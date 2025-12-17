# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell

# poly-secret-mcp - Wolfi Base (Primary)
# Minimal, secure container image using Wolfi (FOSS, no auth required)

FROM cgr.dev/chainguard/wolfi-base:latest

LABEL org.opencontainers.image.title="poly-secret-mcp"
LABEL org.opencontainers.image.description="Multi-backend secrets MCP server (Vault, Infisical, SOPS, Doppler, 1Password)"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.authors="Jonathan D.A. Jewell"
LABEL org.opencontainers.image.source="https://github.com/hyperpolymath/poly-secret-mcp"
LABEL org.opencontainers.image.licenses="MIT"
LABEL dev.mcp.server="true"
LABEL io.modelcontextprotocol.server.name="io.github.hyperpolymath/poly-secret-mcp"

# Install Deno
RUN apk add --no-cache deno ca-certificates

# Create non-root user
RUN adduser -D -u 1000 mcp
WORKDIR /app

# Copy application files
COPY --chown=mcp:mcp deno.json package.json ./
COPY --chown=mcp:mcp index.js ./
COPY --chown=mcp:mcp adapters/ ./adapters/
COPY --chown=mcp:mcp src/ ./src/ 2>/dev/null || true
COPY --chown=mcp:mcp lib/ ./lib/ 2>/dev/null || true

# Cache dependencies
RUN deno cache --config=deno.json index.js

# Switch to non-root user
USER mcp

# Secret manager CLIs (vault, infisical, sops) are expected to be:
# - Mounted from host, OR
# - Available in PATH via container configuration
ENV SECRET_BACKEND=auto

ENTRYPOINT ["deno", "run", "--allow-run", "--allow-read", "--allow-write", "--allow-env", "--allow-net", "index.js"]
