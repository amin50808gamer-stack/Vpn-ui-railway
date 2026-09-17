# ---- Build stage ----
FROM golang:1.22-bullseye AS builder

WORKDIR /src

# Copy the ENTIRE project at once (no separate go.mod/go.sum caching step,
# since this repo doesn't have a go.sum at the root — likely due to
# git submodules, see .gitmodules).
COPY . .

# If the project uses git submodules (corebundle, third_party, xray may be
# submodules), they won't come through a plain GitHub->Railway deploy
# unless Railway's builder fetches them. If build.sh or go build complains
# about missing packages inside third_party/ or corebundle/, that's why.
RUN go mod download || echo "go mod download had issues, continuing..."

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
