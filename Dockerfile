FROM node:18-alpine AS base

# 1. Установка зависимостей
FROM base AS deps
WORKDIR /app
RUN npm install -g pnpm

# Копируем конфиги
COPY package.json pnpm-lock.yaml ./
# Копируем призму для генерации клиента
COPY prisma ./prisma

RUN pnpm i --frozen-lockfile

# 2. Сборка (Builder)
FROM base AS builder
WORKDIR /app
RUN npm install -g pnpm

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# === ВОТ ТУТ МАГИЯ: ЗАГЛУШКИ ДЛЯ СБОРКИ ===
# Мы даем фейковые данные, чтобы валидатор Zod пропустил нас.
# Реальные ключи вы подставите уже когда будете запускать контейнер (в .env или k8s)

# Ссылка должна выглядеть как URL, иначе валидация не пройдет
ENV DATABASE_URL="postgresql://dummy:dummy@localhost:5432/dummy"
ENV NEXTAUTH_URL="http://localhost:3000"

# Остальным достаточно просто быть не пустыми строками
ENV TAVILY_API_KEY="mock_key_for_build"
ENV OPENAI_API_KEY="mock_key_for_build"
ENV TOGETHER_AI_API_KEY="mock_key_for_build"
ENV GOOGLE_CLIENT_ID="mock_key_for_build"
ENV GOOGLE_CLIENT_SECRET="mock_key_for_build"
ENV UNSPLASH_ACCESS_KEY="mock_key_for_build"
ENV NEXTAUTH_SECRET="mock_key_for_build"

# Также попробуем штатный способ отключения валидации (работает в T3 Stack)
ENV SKIP_ENV_VALIDATION=1

# ==========================================

RUN pnpm run build

# Чистим лишнее
RUN pnpm prune --prod

# 3. Финальный образ (Runner)
FROM base AS runner
WORKDIR /app
ENV NODE_ENV production
RUN npm install -g pnpm

COPY package.json pnpm-lock.yaml ./

# Копируем готовые модули и билд
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/prisma ./prisma

EXPOSE 3000
CMD ["pnpm", "start"]
