FROM node:18-alpine AS base

# 1. Установка зависимостей
FROM base AS deps
WORKDIR /app
RUN npm install -g pnpm

COPY package.json pnpm-lock.yaml ./
COPY prisma ./prisma

# Ставим все зависимости (включая dev, чтобы была prisma CLI)
RUN pnpm i --frozen-lockfile

# 2. Сборка (Builder)
FROM base AS builder
WORKDIR /app
RUN npm install -g pnpm

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# === ЗАГЛУШКИ ПЕРЕМЕННЫХ ДЛЯ СБОРКИ ===
# Это нужно, чтобы Next.js не ругался при билде. 
# Реальные ключи вы будете передавать при запуске контейнера.
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
# ======================================

# Генерируем Prisma Client (на всякий случай явно)
RUN npx prisma generate

# Собираем проект
RUN pnpm run build

# !!! ИСПРАВЛЕНИЕ ЗДЕСЬ:
# Удаляем devDependencies, но запрещаем запускать postinstall скрипты,
# чтобы он не пытался вызвать удаленную prisma.
RUN pnpm prune --prod --config.ignore-scripts=true

# 3. Финальный образ (Runner)
FROM base AS runner
WORKDIR /app
ENV NODE_ENV production
RUN npm install -g pnpm

COPY package.json pnpm-lock.yaml ./

# Копируем очищенные node_modules (только prod зависимости)
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/prisma ./prisma

EXPOSE 3000
CMD ["pnpm", "start"]
