FROM node:22-alpine
RUN apk update && apk upgrade && \
    apk add --no-cache \
    curl \
    tini

WORKDIR /usr/local/app

# have nodemon available for local dev use (file watching)
RUN npm install -g nodemon@3.1.0 && \
    npm cache clean --force

COPY package*.json ./

RUN npm ci && \
    npm cache clean --force && \
    mv /usr/local/app/node_modules /node_modules

COPY . .

ENV PORT=80
EXPOSE 80

# In Alpine, tini is installed to /sbin/tini instead of /usr/bin/tini
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]