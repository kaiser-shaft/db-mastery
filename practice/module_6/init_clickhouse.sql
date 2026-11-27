-- ============================================================================
-- МОДУЛЬ 6 (ClickHouse): Подготовка аналитических таблиц в analytics_db
-- ============================================================================
-- Этот скрипт создаёт колончатые таблицы в базе analytics_db для Уроков 6.3 и 6.5:
--   1) m6_sales_raw / m6_sales_opt — 500 000 строк для сравнения сжатия и гранул
--   2) m6_shard_kz / m6_shard_ru / m6_sales_global — мини-MPP на движке Merge
--   3) m6_mart_sales / m6_mart_sales_stage — витрина итогового проекта (Урок 6.5)
--
-- Скрипт идемпотентен: запускай его повторно в любой момент для сброса данных.
-- Перед запуском убедись, что поднят профиль mod6:
--   docker compose --profile mod6 up -d
--
-- Как запустить из терминала (из корневой папки курса):
--   Linux / macOS / Git Bash:
--     docker exec -i course_clickhouse clickhouse-client -u student --password student_pass -d analytics_db --multiquery < practice/module_6/init_clickhouse.sql
--
--   Windows PowerShell:
--     Get-Content practice/module_6/init_clickhouse.sql -Raw | docker exec -i course_clickhouse clickhouse-client -u student --password student_pass -d analytics_db --multiquery
-- ============================================================================

-- 0. Очистка старых таблиц практикума Модуля 6
DROP TABLE IF EXISTS m6_sales_global;
DROP TABLE IF EXISTS m6_shard_kz;
DROP TABLE IF EXISTS m6_shard_ru;
DROP TABLE IF EXISTS m6_sales_raw;
DROP TABLE IF EXISTS m6_sales_opt;
DROP TABLE IF EXISTS m6_mart_sales;
DROP TABLE IF EXISTS m6_mart_sales_stage;
DROP VIEW  IF EXISTS lab_mv_daily_clicks;
DROP TABLE IF EXISTS lab_daily_clicks_agg;
DROP TABLE IF EXISTS lab_raw_clicks;
DROP TABLE IF EXISTS lab_orders_bad;
DROP TABLE IF EXISTS lab_orders_good;
DROP TABLE IF EXISTS lab_metrics;

-- ============================================================================
-- 1. Сырая и оптимизированная таблицы (500 000 строк, Урок 6.3)
-- ============================================================================
CREATE TABLE m6_sales_raw (
    sale_id   UInt64,
    sale_date Date,
    city      String,
    category  String,
    qty       UInt16,
    amount    UInt32,
    comment   String
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(sale_date)
ORDER BY (city, sale_date);

INSERT INTO m6_sales_raw
SELECT
    number + 1 AS sale_id,
    addDays(toDate('2026-01-01'), number % 90) AS sale_date,
    arrayElement(['Алматы', 'Астана', 'Костанай', 'Москва'], (number % 4) + 1) AS city,
    arrayElement(['Электроника', 'Мерч', 'Аксессуары'], (number % 3) + 1) AS category,
    1 + (number % 3) AS qty,
    (1 + (number % 3)) * (5000 + (number % 5) * 3000) AS amount,
    concat('Подробный комментарий менеджера к чеку номер #', toString(number + 1)) AS comment
FROM numbers(500000);

CREATE TABLE m6_sales_opt (
    sale_id   UInt64 CODEC(Delta, ZSTD(3)),
    sale_date Date   CODEC(DoubleDelta, ZSTD(3)),
    city      LowCardinality(String),
    category  LowCardinality(String),
    qty       UInt16 CODEC(ZSTD(3)),
    amount    UInt32 CODEC(ZSTD(3)),
    comment   String CODEC(ZSTD(3))
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(sale_date)
ORDER BY (city, sale_date);

INSERT INTO m6_sales_opt SELECT * FROM m6_sales_raw;

-- ============================================================================
-- 2. Мини-MPP: два локальных шарда + объединяющая таблица Merge (Урок 6.3)
-- ============================================================================
CREATE TABLE m6_shard_kz (
    sale_date Date,
    city      LowCardinality(String),
    amount    UInt32
)
ENGINE = MergeTree()
ORDER BY (city, sale_date);

CREATE TABLE m6_shard_ru (
    sale_date Date,
    city      LowCardinality(String),
    amount    UInt32
)
ENGINE = MergeTree()
ORDER BY (city, sale_date);

INSERT INTO m6_shard_kz
SELECT sale_date, city, amount
FROM m6_sales_opt
WHERE city IN ('Алматы', 'Астана', 'Костанай');

INSERT INTO m6_shard_ru
SELECT sale_date, city, amount
FROM m6_sales_opt
WHERE city = 'Москва';

CREATE TABLE m6_sales_global AS m6_shard_kz
ENGINE = Merge(currentDatabase(), '^m6_shard_');

-- ============================================================================
-- 3. Сквозная витрина итогового проекта (Урок 6.5)
-- Стартовое состояние: загружен ТОЛЬКО Январь 2026 (3 строки, 89 000.00),
-- чтобы в Уроке 6.5 ты сначала поймал MISMATCH в DQ-сверке, а затем
-- атомарно подлил Февраль через m6_mart_sales_stage + REPLACE PARTITION!
-- ============================================================================
CREATE TABLE m6_mart_sales (
    item_bk       UInt32 CODEC(Delta, ZSTD(3)),
    order_bk      UInt32 CODEC(Delta, ZSTD(3)),
    order_date    Date   CODEC(DoubleDelta, ZSTD(3)),
    customer_bk   UInt32,
    city_name     LowCardinality(String),
    segment       LowCardinality(String),
    product_title LowCardinality(String),
    category_name LowCardinality(String),
    qty           UInt16,
    total_amount  Decimal(12, 2)
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(order_date)
ORDER BY (city_name, category_name, order_date);

CREATE TABLE m6_mart_sales_stage AS m6_mart_sales;

INSERT INTO m6_mart_sales VALUES
    (1, 1001, '2026-01-12', 1, 'Костанай', 'Standard', 'Механическая клавиатура', 'Электроника', 1, 33000.00),
    (2, 1001, '2026-01-12', 1, 'Костанай', 'Standard', 'Термокружка кодера',      'Аксессуары',  2, 16000.00),
    (3, 1002, '2026-01-18', 2, 'Алматы',   'VIP',      'Худи «SQL Master»',       'Мерч',        2, 40000.00);

-- ============================================================================
-- Итоговая сводка загруженных строк по таблицам ClickHouse
-- ============================================================================
SELECT 'm6_sales_raw'        AS table_name, count() AS rows_count FROM m6_sales_raw
UNION ALL
SELECT 'm6_sales_opt',        count() FROM m6_sales_opt
UNION ALL
SELECT 'm6_shard_kz',         count() FROM m6_shard_kz
UNION ALL
SELECT 'm6_shard_ru',         count() FROM m6_shard_ru
UNION ALL
SELECT 'm6_sales_global',     count() FROM m6_sales_global
UNION ALL
SELECT 'm6_mart_sales',       count() FROM m6_mart_sales
UNION ALL
SELECT 'm6_mart_sales_stage', count() FROM m6_mart_sales_stage;
