# Use Node.js 18 LTS as base image
FROM node:18-alpine

# Install pnpm and curl (for health checks)
RUN npm install -g pnpm@latest-10 && \
    apk add --no-cache curl

# Set working directory
WORKDIR /app

# Copy package files and patches directory (needed for pnpm install)
COPY package.json pnpm-lock.yaml ./
COPY patches ./patches

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy application files
COPY . .

# Build Strapi application
RUN pnpm build

# Expose port
EXPOSE 1337

# Set environment to production
ENV NODE_ENV=production

# Start Strapi
CMD ["pnpm", "start"]

