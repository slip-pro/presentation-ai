FROM node:18-alpine AS base

# 1. Установка зависимостей
FROM base AS deps
WORKDIR /app
RUN npm install -g pnpm

# Копируем конфиги
COPY package.json pnpm-lock.yaml ./
# !!! ВАЖНО: Копируем папку prisma ПЕРЕД установкой, 
# чтобы скрипт postinstall (prisma generate) нашел схему
COPY prisma ./prisma

# Теперь установка пройдет успешно, так как schema.prisma на месте
RUN pnpm i --frozen-lockfile

# 2. Сборка (Builder)
FROM base AS builder
WORKDIR /app
RUN npm install -g pnpm

# Забираем установленные модули
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Собираем проект
RUN pnpm run build

# !!! ЧИСТКА: Удаляем devDependencies (типа typescript, eslint), 
# но оставляем сгенерированный Prisma Client
RUN pnpm prune --prod

# 3. Финальный образ (Runner)
FROM base AS runner
WORKDIR /app
ENV NODE_ENV production
# Устанавливаем npm/pnpm для запуска (на всякий случай)
RUN npm install -g pnpm

COPY package.json pnpm-lock.yaml ./

# !!! ХИТРОСТЬ: Мы не запускаем install здесь снова.
# Мы просто копируем уже готовые "чистые" модули из builder.
# Это предотвращает ошибку "prisma not found" и ускоряет запуск.
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
# Иногда в проде нужна схема для работы движка Prisma
COPY --from=builder /app/prisma ./prisma

EXPOSE 3000
CMD ["pnpm", "start"]
