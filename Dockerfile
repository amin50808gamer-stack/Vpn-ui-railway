# ---- Build stage ----
FROM golang:1.22-bullseye AS builder

WORKDIR /src

# Copy go.mod/go.sum first for better layer caching
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the project (main.go, web/, xray/, corebundle/, config/, etc.)
COPY . .

# The project ships its own build.sh which likely bundles Xray-core,
# geo files, and the web frontend into the final binary.
# If build.sh assumes root / systemd / a specific OS, it may need editing —
# check its contents (view it on GitHub: /blob/main/build.sh) before relying
# on this blindly.
RUN chmod +x build.sh && ./build.sh || \
    (echo "build.sh failed — falling back to plain go build" && \
     go build -o vpn-ui-amd64 .)

# ---- Runtime stage ----
FROM debian:bullseye-slim

# Common runtime deps that Xray-core / the panel binary usually need.
# PPTP/L2TP/OpenVPN daemons will NOT function here — Railway containers
# have no /dev/net/tun and no NET_ADMIN capability, so those protocols
# will fail even though the binary is present.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the built binary and any assets it needs at runtime
COPY --from=builder /src/vpn-ui-amd64 ./vpn-ui-amd64
COPY --from=builder /src/web ./web
COPY --from=builder /src/config ./config

# Railway injects the port to listen on via $PORT — make sure the panel
# reads this env var (check .env.example / config/ for the right variable
# name, it may be called PORT, PANEL_PORT, or similar).
ENV PORT=3000
EXPOSE 3000

CMD ["./vpn-ui-amd64"]
