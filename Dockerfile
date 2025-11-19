FROM node:18-alpine AS base

# 1. Установка зависимостей
FROM base AS deps
WORKDIR /app
# Ставим сам pnpm
RUN npm install -g pnpm
COPY package.json pnpm-lock.yaml ./
RUN pnpm i --frozen-lockfile

# 2. Сборка
FROM base AS builder
WORKDIR /app
RUN npm install -g pnpm
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm run build

# 3. Финальный образ
FROM base AS runner
WORKDIR /app
ENV NODE_ENV production
RUN npm install -g pnpm

COPY package.json pnpm-lock.yaml ./
RUN pnpm i --prod --frozen-lockfile

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next

EXPOSE 3000
CMD ["pnpm", "start"]
