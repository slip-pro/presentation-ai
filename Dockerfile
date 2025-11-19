# Используем Node.js 18 на Alpine Linux
FROM node:18-alpine AS base

# 1. Установка зависимостей для сборки
FROM base AS deps
WORKDIR /app
# Копируем файлы описания пакетов
COPY package.json package-lock.json ./
# Устанавливаем все зависимости (включая dev, нужны для билда)
RUN npm ci

# 2. Сборка проекта (Builder)
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# Запускаем сборку Next.js
RUN npm run build

# 3. Финальный образ (Runner)
FROM base AS runner
WORKDIR /app
ENV NODE_ENV production

# Копируем package.json, чтобы установить чистовые зависимости
COPY package.json package-lock.json ./

# Устанавливаем ТОЛЬКО production-зависимости (без dev)
# Это поможет немного уменьшить размер образа, хоть и не так сильно, как standalone
RUN npm ci --omit=dev

# Копируем результаты сборки из этапа Builder
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next

# Открываем порт и запускаем
EXPOSE 3000
CMD ["npm", "start"]
