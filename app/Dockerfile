# ---------- Stage 1 ----------
FROM node:20.18.1-alpine3.20 AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY src ./src

# ---------- Stage 2 ----------
FROM node:20.18.1-alpine3.20
ARG APP_VERSION=1.0.0

LABEL org.opencontainers.image.title="devops-task" \
      org.opencontainers.image.description="Small web service for the DevOps assessment" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.source="https://github.com/shilemon/care_guide"

ENV NODE_ENV=production \
    PORT=3000 \
    APP_VERSION=${APP_VERSION}

WORKDIR /app
# Only copy the result of the build stage (no npm cache, no dev tools)
COPY --from=build --chown=node:node /app ./

# Run as the non-root "node" user that ships with the image
USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "src/server.js"]
