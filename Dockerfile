# ------------------------------------------------------------------
# Dockerfile for deploying Sir-MmD/vpn-ui on Railway
#
# IMPORTANT / مهم:
# This panel is designed to run on a full Linux host with root access,
# kernel modules, nftables, and systemd. Railway containers do NOT
# provide any of that. This build will compile and start the web
# server, but VPN protocols (L2TP, PPTP, OpenVPN, etc.) will NOT
# function. This is a UI-only deployment.
#
# این پنل برای اجرا روی یک سرور کامل لینوکسی با دسترسی root طراحی شده.
# روی Railway، پروتکل‌های VPN کار نخواهند کرد. این فقط رابط وب است.
# ------------------------------------------------------------------

FROM golang:1.22-bookworm AS builder

WORKDIR /src

# Clone the repository at build time (always gets latest main branch)
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/Sir-MmD/vpn-ui.git .

# Fetch git submodules if any (repo has .gitmodules)
RUN git submodule update --init --recursive || true

# Download Go module dependencies
RUN go mod download

# Build the binary. If build.sh exists and works better than a plain
# `go build`, try it first; otherwise fall back to a direct build.
RUN go build -o /out/vpn-ui-app . || \
    (chmod +x ./build.sh && ./build.sh && cp ./build/* /out/vpn-ui-app 2>/dev/null || true)

# ------------------------------------------------------------------
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /out/vpn-ui-app /app/vpn-ui-app

# Railway injects PORT at runtime; the app must listen on it.
# We pass it through as an env var — you may need to adjust the app's
# config (config/ or .env) if it expects a fixed port instead of $PORT.
ENV PORT=8080
EXPOSE 8080

CMD ["/app/vpn-ui-app"]
