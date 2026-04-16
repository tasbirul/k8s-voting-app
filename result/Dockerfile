FROM node:18-slim

# Use wildcards (*) to satisfy the linter while allowing minor patch updates.
# This prevents the build from breaking during Debian point releases.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl=8.* \
    tini=0.19.* && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/app

# Pin nodemon to a specific major/minor version
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