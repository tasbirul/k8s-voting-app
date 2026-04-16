FROM node:18-slim

# Pin versions for apt-get packages (DL3008)
# versions 7.88.1-10+deb12u8 and 0.19.0-1 are standard for Debian 12 (Bookworm)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl=7.88.1-10+deb12u8 \
    tini=0.19.0-1 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/app

# Pin the version for global npm installs (DL3016)
RUN npm install -g nodemon@3.0.1 && npm cache clean --force

COPY package*.json ./
RUN npm ci && \
    npm cache clean --force && \
    mv /usr/local/app/node_modules /node_modules

COPY . .

ENV PORT=80
EXPOSE 80

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "server.js"]