FROM node:18-alpine AS base

# 1. Установка зависимостей
FROM base AS deps
WORKDIR /app
RUN npm install -g pnpm

COPY package.json pnpm-lock.yaml ./
COPY prisma ./prisma

RUN pnpm i --frozen-lockfile

# 2. Сборка (Builder)
FROM base AS builder
WORKDIR /app
RUN npm install -g pnpm

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# !!! ИСПРАВЛЕНИЕ: Создаем папку public, если её нет в репо.
# Это спасет от ошибки "not found", если автор удалил папку.
RUN mkdir -p public

# === ЗАГЛУШКИ ПЕРЕМЕННЫХ ===
ENV SKIP_ENV_VALIDATION=1
ENV DATABASE_URL="postgresql://dummy:dummy@localhost:5432/dummy"
ENV NEXTAUTH_URL="http://localhost:3000"
ENV TAVILY_API_KEY="mock"
ENV OPENAI_API_KEY="mock"
ENV TOGETHER_AI_API_KEY="mock"
ENV GOOGLE_CLIENT_ID="mock"
ENV GOOGLE_CLIENT_SECRET="mock"
ENV UNSPLASH_ACCESS_KEY="mock"
ENV NEXTAUTH_SECRET="mock"
# ===========================

RUN npx prisma generate
RUN pnpm run build

# Чистим dev-зависимости без запуска скриптов
RUN pnpm prune --prod --config.ignore-scripts=true

# 3. Финальный образ (Runner)
FROM base AS runner
WORKDIR /app
ENV NODE_ENV production
RUN npm install -g pnpm

COPY package.json pnpm-lock.yaml ./

# Копируем
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/prisma ./prisma

EXPOSE 3000
CMD ["pnpm", "start"]
