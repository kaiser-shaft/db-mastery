-- ============================================================================
-- МОДУЛЬ 3: Подготовка учебной базы данных (Внутреннее устройство PostgreSQL)
-- ============================================================================
-- Этот скрипт создаёт 5 таблиц в базе learning_db и наполняет их детерминиро-
-- ванными данными для практики по Урокам 3.1–3.4 (страницы 8 КБ, Heap/ctid,
-- Shared Buffers, индексы B-Tree / GIN / BRIN, EXPLAIN ANALYZE и WAL):
--   m3_backpack     (5 строк)       — мини-таблица (1 страница) для опытов с ctid
--   m3_customers    (1 000 строк)   — клиенты (смешанный регистр email, 10% NULL)
--   m3_products     (200 строк)     — товары с TEXT[] (tags) и JSONB (specs)
--   m3_orders       (100 000 строк) — заказы без лишних индексов (для Seq/Index Scan)
--   m3_sensor_logs  (200 000 строк) — хронологические логи (для BRIN, GIN, Partial)
--
-- Скрипт идемпотентен: его можно запускать повторно в любой момент — он
-- безопасно пересоздаст таблицы (удаляя и временные учебные таблицы/индексы)
-- и вернёт базу в исходное состояние.
--
-- Как запустить из терминала (из корневой папки курса):
--   Linux / macOS / Git Bash:
--     docker exec -i course_pg_primary psql -U student -d learning_db < practice/module_3/init.sql
--
--   Windows PowerShell:
--     Get-Content practice/module_3/init.sql -Raw | docker exec -i course_pg_primary psql -U student -d learning_db
--
-- Либо просто открой этот файл в DBeaver / DataGrip / Adminer и выполни целиком.
-- ============================================================================

-- 1. Удаляем старые и вспомогательные таблицы заданий в правильном порядке
DROP TABLE IF EXISTS m3_fpi_lab CASCADE;
DROP TABLE IF EXISTS m3_unlogged_bench CASCADE;
DROP TABLE IF EXISTS m3_logged_bench CASCADE;
DROP TABLE IF EXISTS m3_wal_lab CASCADE;
DROP TABLE IF EXISTS m3_sensor_logs CASCADE;
DROP TABLE IF EXISTS m3_orders CASCADE;
DROP TABLE IF EXISTS m3_products CASCADE;
DROP TABLE IF EXISTS m3_customers CASCADE;
DROP TABLE IF EXISTS m3_backpack CASCADE;

-- 2. Компактная таблица на 5 строк (1 страница = 8 КБ) для наблюдений за Heap и ctid
CREATE TABLE m3_backpack (
    id       INT PRIMARY KEY,
    item     TEXT NOT NULL,
    category TEXT NOT NULL,
    price    INT NOT NULL CHECK (price > 0),
    note     TEXT -- NULL = комментарий не указан
);

-- 3. Клиенты (1 000 строк: смешанный регистр email для ловушки LOWER(), 10% NULL в phone)
CREATE TABLE m3_customers (
    id        INT PRIMARY KEY,
    full_name TEXT NOT NULL,
    email     TEXT NOT NULL UNIQUE,
    city      TEXT NOT NULL,
    phone     TEXT, -- NULL у каждого 10-го клиента
    tier      TEXT NOT NULL CHECK (tier IN ('standard', 'pro', 'vip'))
);

-- 4. Товары (200 строк: массивы тегов TEXT[] и характеристики JSONB)
CREATE TABLE m3_products (
    id       INT PRIMARY KEY,
    sku      TEXT NOT NULL UNIQUE,
    title    TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('electronics', 'books', 'clothes', 'games')),
    price    NUMERIC(10, 2) NOT NULL CHECK (price > 0),
    tags     TEXT[] NOT NULL,
    specs    JSONB NOT NULL
);

-- 5. Заказы (100 000 строк: специально БЕЗ доп. индексов, кроме PRIMARY KEY)
--    Распределение status: 5% 'pending', 10% 'cancelled', 85% 'paid'
CREATE TABLE m3_orders (
    id          INT PRIMARY KEY,
    order_code  TEXT NOT NULL,
    customer_id INT NOT NULL REFERENCES m3_customers(id) ON DELETE RESTRICT,
    product_id  INT NOT NULL REFERENCES m3_products(id)  ON DELETE RESTRICT,
    status      TEXT NOT NULL CHECK (status IN ('pending', 'paid', 'cancelled')),
    amount      NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    created_at  TIMESTAMPTZ NOT NULL
);

-- 6. Хронологические логи датчиков (200 000 строк: append-only по logged_at)
--    Распределение severity: 2% 'critical', 8% 'warn', 90% 'info'
CREATE TABLE m3_sensor_logs (
    id        BIGINT PRIMARY KEY,
    sensor_id INT NOT NULL,
    severity  TEXT NOT NULL CHECK (severity IN ('info', 'warn', 'critical')),
    temp_c    NUMERIC(5, 2) NOT NULL,
    tags      TEXT[] NOT NULL,
    payload   JSONB NOT NULL,
    logged_at TIMESTAMPTZ NOT NULL
);

-- ============================================================================
-- Наполняем таблицы детерминированными данными
-- ============================================================================

INSERT INTO m3_backpack (id, item, category, price, note) VALUES
    (1, 'Железный меч',      'weapon', 500, 'Базовый предмет'),
    (2, 'Деревянный щит',    'armor',  300, 'Для новичка'),
    (3, 'Зелье здоровья',    'potion',  50, 'Восстанавливает HP'),
    (4, 'Факел разведчика',  'tool',   120, NULL),
    (5, 'Свиток телепорта',  'magic',  900, 'Одноразовый');

INSERT INTO m3_customers (id, full_name, email, city, phone, tier)
SELECT
    g,
    'Клиент #' || g,
    'User' || g || '@Shop.KZ',
    (ARRAY['Алматы', 'Астана', 'Костанай', 'Шымкент', 'Караганда'])[1 + ((g - 1) % 5)],
    CASE
        WHEN g % 10 = 0 THEN NULL
        ELSE '+7-701-' || LPAD(g::TEXT, 7, '0')
    END,
    CASE
        WHEN g % 20 = 0 THEN 'vip'      -- 5% (50 клиентов)
        WHEN g % 5  = 0 THEN 'pro'      -- 15% (150 клиентов)
        ELSE 'standard'                 -- 80% (800 клиентов)
    END
FROM generate_series(1, 1000) AS g;

INSERT INTO m3_products (id, sku, title, category, price, tags, specs)
SELECT
    g,
    'SKU-' || LPAD(g::TEXT, 4, '0'),
    'Товар #' || g,
    (ARRAY['electronics', 'books', 'clothes', 'games'])[1 + ((g - 1) % 4)],
    (500 + ((g * 37) % 15000))::NUMERIC(10, 2),
    CASE
        WHEN g % 25 = 0 THEN ARRAY['postgresql', 'hit', 'wal']
        WHEN g % 4  = 1 THEN ARRAY['gadget', 'tech', 'hit']
        WHEN g % 4  = 2 THEN ARRAY['book', 'sql']
        WHEN g % 4  = 3 THEN ARRAY['merch', 'cotton']
        ELSE ARRAY['game', 'fun']
    END,
    jsonb_build_object(
        'brand',      CASE WHEN g % 20 = 0 THEN 'Pixel' WHEN g % 2 = 0 THEN 'KeyPro' ELSE 'Nord' END,
        'in_stock',   (g % 5 <> 0),
        'warranty_m', CASE WHEN g % 4 = 1 THEN 24 ELSE 12 END
    )
FROM generate_series(1, 200) AS g;

INSERT INTO m3_orders (id, order_code, customer_id, product_id, status, amount, created_at)
SELECT
    g,
    'ORD-' || LPAD(g::TEXT, 6, '0'),
    1 + ((g * 37) % 1000),
    1 + ((g * 13) % 200),
    CASE
        WHEN g % 20 = 0 THEN 'pending'    -- 5% (5 000 заказов)
        WHEN g % 10 = 1 THEN 'cancelled'  -- 10% (10 000 заказов)
        ELSE 'paid'                       -- 85% (85 000 заказов)
    END,
    (500 + ((g * 19) % 45000))::NUMERIC(10, 2),
    TIMESTAMPTZ '2026-01-01 00:00:00+05' + (g * INTERVAL '2 minutes')
FROM generate_series(1, 100000) AS g;

INSERT INTO m3_sensor_logs (id, sensor_id, severity, temp_c, tags, payload, logged_at)
SELECT
    g,
    1 + ((g - 1) % 50),
    CASE
        WHEN g % 50 = 0 THEN 'critical'   -- 2% (4 000 записей)
        WHEN g % 10 = 0 THEN 'warn'       -- 8% (16 000 записей)
        ELSE 'info'                       -- 90% (180 000 записей)
    END,
    ROUND((18.00 + ((g * 13) % 1200) / 100.0)::NUMERIC, 2),
    CASE
        WHEN g % 500 = 0 THEN ARRAY['wal', 'disk', 'alert']
        WHEN g % 5   = 0 THEN ARRAY['cpu', 'metrics']
        ELSE ARRAY['sensor', 'ok']
    END,
    jsonb_build_object(
        'zone',     CASE WHEN g % 500 = 0 THEN 'dc-1' WHEN g % 2 = 0 THEN 'dc-2' ELSE 'dc-3' END,
        'critical', (g % 50 = 0)
    ),
    TIMESTAMPTZ '2026-01-01 00:00:00+05' + (g * INTERVAL '10 seconds')
FROM generate_series(1, 200000) AS g;

-- Обновляем статистику (pg_stats) и карту видимости (Visibility Map)
VACUUM ANALYZE m3_backpack, m3_customers, m3_products, m3_orders, m3_sensor_logs;

-- Быстрая проверка, что всё загрузилось:
SELECT 'm3_backpack'    AS table_name, COUNT(*) AS rows_count FROM m3_backpack
UNION ALL
SELECT 'm3_customers',   COUNT(*) FROM m3_customers
UNION ALL
SELECT 'm3_products',    COUNT(*) FROM m3_products
UNION ALL
SELECT 'm3_orders',      COUNT(*) FROM m3_orders
UNION ALL
SELECT 'm3_sensor_logs', COUNT(*) FROM m3_sensor_logs;
