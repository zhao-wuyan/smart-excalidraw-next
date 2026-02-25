FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
WORKDIR /app

# Disable SSL verification for npm (for corporate proxies/firewalls)
RUN npm config set strict-ssl false

# Use China mirror for faster and more reliable downloads
RUN npm config set registry https://registry.npmmirror.com

# Install pnpm globally
RUN npm install -g pnpm@9.12.3

# Configure pnpm to use China mirror
RUN pnpm config set registry https://registry.npmmirror.com
RUN pnpm config set strict-ssl false

# Copy package files
COPY package.json pnpm-lock.yaml* ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app

# Disable SSL verification and use China mirror
RUN npm config set strict-ssl false
RUN npm config set registry https://registry.npmmirror.com

# Install pnpm globally
RUN npm install -g pnpm@9.12.3

# Configure pnpm
RUN pnpm config set registry https://registry.npmmirror.com
RUN pnpm config set strict-ssl false

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build the application
RUN pnpm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
ENV PORT 5555
ENV HOSTNAME "0.0.0.0"
# Disable SSL verification for Node.js fetch (for corporate proxies)
ENV NODE_TLS_REJECT_UNAUTHORIZED 0

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Set the correct permission for prerender cache
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Automatically leverage output traces to reduce image size
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 5555

CMD ["node", "server.js"]
