# syntax=docker/dockerfile:1
# ---- Build Stage ----
FROM node:22-alpine AS builder

WORKDIR /usr/local/app

COPY package*.json ./

# Install production dependencies only, then cache-bust npm cache
RUN npm ci --omit=dev && \
    npm cache clean --force

# ---- Production Stage ----
FROM node:22-alpine

# Install OS-level security updates and tini (init system)
RUN apk add --no-cache tini

WORKDIR /usr/local/app

# Copy only production node_modules from builder stage
COPY --from=builder /usr/local/app/node_modules ./node_modules

# Copy application source
COPY . .

ENV PORT=80
EXPOSE 80

# Run as non-root user for security (DL3002)
USER node

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]