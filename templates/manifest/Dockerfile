# ── Stage 1: dependency install ───────────────────────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app

# Copy only package files first → layer cache stays valid unless deps change
COPY package.json ./
RUN npm install --omit=dev --frozen-lockfile

# ── Stage 2: production image ─────────────────────────────────────────────────
FROM node:20-alpine AS runner
WORKDIR /app

# Security: run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copy installed modules and source
COPY --from=deps /app/node_modules ./node_modules
COPY --chown=appuser:appgroup . .

# Expose API port
EXPOSE 3001

# Health check used by Docker Compose / K8s readiness probes
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3001/health || exit 1

CMD ["node", "server.js"]
