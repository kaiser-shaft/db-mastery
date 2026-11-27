-- ============================================================================
-- МОДУЛЬ 6 (PostgreSQL 16): Подготовка учебной базы DWH, партиций, ELT и SCD2
-- ============================================================================
-- Этот скрипт создаёт 4 учебные схемы в базе learning_db для Уроков 6.1, 6.2,
-- 6.4 и 6.5 (а для Уроков 6.3 и 6.5 дополнительно загрузи init_clickhouse.sql):
--   1) m6_oltp — нормализованный боевой магазин (3НФ, 7 таблиц)
--   2) m6_star — готовая схема «Звезда» (dim_date, dim_product, dim_customer, fact_sales)
--   3) m6_part — партиционированная таблица фактов (90 000 строк) + MATERIALIZED VIEW
--   4) m6_elt  — буферы ELT, история SCD Type 2, факты и шлюз export_sales_mart для ClickHouse
--
-- Скрипт идемпотентен: запускай его повторно в любой момент, чтобы сбросить
-- все схемы Модуля 6 в исходное состояние.
--
-- Как запустить из терминала (из корневой папки курса):
--   Linux / macOS / Git Bash:
--     docker exec -i course_pg_primary psql -U student -d learning_db < practice/module_6/init.sql
--
--   Windows PowerShell:
--     Get-Content practice/module_6/init.sql -Raw | docker exec -i course_pg_primary psql -U student -d learning_db
--
-- Либо открой этот файл в DBeaver / DataGrip / Adminer и выполни целиком.
-- ============================================================================

-- 0. Полная очистка схем Модуля 6 для безопасного повторного запуска
DROP SCHEMA IF EXISTS m6_oltp CASCADE;
DROP SCHEMA IF EXISTS m6_star CASCADE;
DROP SCHEMA IF EXISTS m6_part CASCADE;
DROP SCHEMA IF EXISTS m6_elt  CASCADE;

CREATE SCHEMA m6_oltp;
CREATE SCHEMA m6_star;
CREATE SCHEMA m6_part;
CREATE SCHEMA m6_elt;

-- ============================================================================
-- 1. СХЕМА m6_oltp: Нормализованный интернет-магазин (3НФ, Урок 6.1)
-- ============================================================================
CREATE TABLE m6_oltp.countries (
    id   INT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE m6_oltp.cities (
    id         INT PRIMARY KEY,
    name       TEXT NOT NULL,
    country_id INT NOT NULL REFERENCES m6_oltp.countries(id)
);

CREATE TABLE m6_oltp.categories (
    id   INT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE m6_oltp.products (
    id            INT PRIMARY KEY,
    title         TEXT NOT NULL UNIQUE,
    category_id   INT NOT NULL REFERENCES m6_oltp.categories(id),
    current_price NUMERIC(10, 2) NOT NULL CHECK (current_price > 0)
);

CREATE TABLE m6_oltp.customers (
    id            INT PRIMARY KEY,
    full_name     TEXT NOT NULL,
    city_id       INT NOT NULL REFERENCES m6_oltp.cities(id),
    segment       TEXT NOT NULL CHECK (segment IN ('Standard', 'VIP')),
    referral_code TEXT -- NULL = пришёл без реферального кода
);

CREATE TABLE m6_oltp.orders (
    id           INT PRIMARY KEY,
    customer_id  INT NOT NULL REFERENCES m6_oltp.customers(id),
    order_date   DATE NOT NULL,
    status       TEXT NOT NULL CHECK (status IN ('paid', 'cancelled')),
    delivery_fee NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (delivery_fee >= 0),
    comment      TEXT -- NULL = комментария нет
);

CREATE TABLE m6_oltp.order_items (
    id                INT PRIMARY KEY,
    order_id          INT NOT NULL REFERENCES m6_oltp.orders(id),
    product_id        INT NOT NULL REFERENCES m6_oltp.products(id),
    qty               INT NOT NULL CHECK (qty > 0),
    price_at_purchase NUMERIC(10, 2) NOT NULL CHECK (price_at_purchase > 0),
    discount          NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (discount >= 0)
);

INSERT INTO m6_oltp.countries (id, name) VALUES
    (1, 'Казахстан'),
    (2, 'Россия');

INSERT INTO m6_oltp.cities (id, name, country_id) VALUES
    (1, 'Костанай', 1),
    (2, 'Алматы',   1),
    (3, 'Астана',   1),
    (4, 'Москва',   2);

INSERT INTO m6_oltp.categories (id, name) VALUES
    (1, 'Электроника'),
    (2, 'Мерч'),
    (3, 'Аксессуары');

INSERT INTO m6_oltp.products (id, title, category_id, current_price) VALUES
    (101, 'Механическая клавиатура', 1, 35000.00),
    (102, 'Беспроводная мышь',       1, 18000.00),
    (103, 'Худи «SQL Master»',       2, 22000.00),
    (104, 'Термокружка кодера',      3,  8000.00),
    (105, 'Коврик для мыши XL',      3,  6000.00);

INSERT INTO m6_oltp.customers (id, full_name, city_id, segment, referral_code) VALUES
    (1, 'Айгерим Сатова',  2, 'VIP',      'PROMO_VIP'),
    (2, 'Тимур Искаков',   1, 'Standard', NULL),
    (3, 'Елена Морозова',  4, 'VIP',      'FRIEND26'),
    (4, 'Данияр Алимов',   3, 'Standard', NULL),
    (5, 'Алина Нурланова', 2, 'Standard', NULL); -- без заказов

INSERT INTO m6_oltp.orders (id, customer_id, order_date, status, delivery_fee, comment) VALUES
    (1001, 1, '2026-01-10', 'paid',      1500.00, 'Доставка до двери'), -- Q1, суббота
    (1002, 2, '2026-01-15', 'paid',      1000.00, NULL),                -- Q1, четверг
    (1003, 3, '2026-02-07', 'paid',      2000.00, 'Хрупкий груз'),      -- Q1, суббота
    (1004, 4, '2026-02-18', 'cancelled', 1500.00, 'Клиент отменил'),    -- Q1, отменён!
    (1005, 1, '2026-03-14', 'paid',      1500.00, NULL),                -- Q1, суббота
    (1006, 2, '2026-03-20', 'paid',      1000.00, NULL),                -- Q1, пятница
    (1007, 3, '2026-04-05', 'paid',      2000.00, 'Повторный заказ');   -- Q2, воскресенье

INSERT INTO m6_oltp.order_items (id, order_id, product_id, qty, price_at_purchase, discount) VALUES
    (1,  1001, 101, 1, 32000.00, 2000.00), -- старая цена 32 000 (в каталоге уже 35 000!)
    (2,  1001, 104, 2,  8000.00,    0.00),
    (3,  1002, 103, 1, 22000.00,    0.00),
    (4,  1002, 105, 1,  6000.00,  500.00),
    (5,  1003, 101, 1, 35000.00,    0.00),
    (6,  1003, 102, 2, 18000.00, 1000.00),
    (7,  1004, 101, 3, 35000.00,    0.00), -- позиция отменённого заказа
    (8,  1005, 103, 2, 22000.00, 4000.00),
    (9,  1006, 102, 1, 18000.00,    0.00),
    (10, 1006, 104, 1,  8000.00,    0.00),
    (11, 1007, 103, 1, 22000.00,    0.00);

-- ============================================================================
-- 2. СХЕМА m6_star: Схема «Звезда» (Star Schema, Урок 6.1)
-- ============================================================================
CREATE TABLE m6_star.dim_date (
    date_sk     INT PRIMARY KEY,      -- YYYYMMDD, например 20260110
    full_date   DATE NOT NULL UNIQUE,
    year_num    INT NOT NULL,
    quarter_num INT NOT NULL,
    month_num   INT NOT NULL,
    day_of_week INT NOT NULL,         -- 1 = Пн ... 7 = Вс
    is_weekend  BOOLEAN NOT NULL
);

CREATE TABLE m6_star.dim_product (
    product_sk    SERIAL PRIMARY KEY,
    product_bk    INT NOT NULL UNIQUE,
    product_title TEXT NOT NULL,
    category_name TEXT NOT NULL
);

CREATE TABLE m6_star.dim_customer (
    customer_sk  SERIAL PRIMARY KEY,
    customer_bk  INT NOT NULL UNIQUE,
    full_name    TEXT NOT NULL,
    segment      TEXT NOT NULL,
    city_name    TEXT NOT NULL,
    country_name TEXT NOT NULL
);

-- Зерно (Grain): 1 позиция товара в оплаченном заказе
CREATE TABLE m6_star.fact_sales (
    sale_sk         BIGSERIAL PRIMARY KEY,
    order_bk        INT NOT NULL,
    date_sk         INT NOT NULL REFERENCES m6_star.dim_date(date_sk),
    product_sk      INT NOT NULL REFERENCES m6_star.dim_product(product_sk),
    customer_sk     INT NOT NULL REFERENCES m6_star.dim_customer(customer_sk),
    qty             INT NOT NULL CHECK (qty > 0),
    unit_price      NUMERIC(10, 2) NOT NULL,
    discount_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total_amount    NUMERIC(10, 2) NOT NULL
);

-- Наполняем измерения (всегда РАНЬШЕ таблицы фактов!)
INSERT INTO m6_star.dim_date
    (date_sk, full_date, year_num, quarter_num, month_num, day_of_week, is_weekend)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT,
    d::DATE,
    EXTRACT(YEAR FROM d)::INT,
    EXTRACT(QUARTER FROM d)::INT,
    EXTRACT(MONTH FROM d)::INT,
    EXTRACT(ISODOW FROM d)::INT,
    EXTRACT(ISODOW FROM d) IN (6, 7)
FROM generate_series(DATE '2026-01-01', DATE '2026-12-31', INTERVAL '1 day') AS d;

INSERT INTO m6_star.dim_product (product_bk, product_title, category_name)
SELECT p.id, p.title, c.name
FROM m6_oltp.products p
JOIN m6_oltp.categories c ON c.id = p.category_id
ORDER BY p.id;

INSERT INTO m6_star.dim_customer (customer_bk, full_name, segment, city_name, country_name)
SELECT cu.id, cu.full_name, cu.segment, ci.name, co.name
FROM m6_oltp.customers cu
JOIN m6_oltp.cities    ci ON ci.id = cu.city_id
JOIN m6_oltp.countries co ON co.id = ci.country_id
ORDER BY cu.id;

INSERT INTO m6_star.fact_sales
    (order_bk, date_sk, product_sk, customer_sk, qty, unit_price, discount_amount, total_amount)
SELECT
    o.id,
    TO_CHAR(o.order_date, 'YYYYMMDD')::INT,
    dp.product_sk,
    dc.customer_sk,
    oi.qty,
    oi.price_at_purchase,
    oi.discount,
    (oi.qty * oi.price_at_purchase - oi.discount)
FROM m6_oltp.order_items oi
JOIN m6_oltp.orders       o  ON o.id          = oi.order_id
JOIN m6_star.dim_product  dp ON dp.product_bk = oi.product_id
JOIN m6_star.dim_customer dc ON dc.customer_bk = o.customer_id
WHERE o.status = 'paid'
ORDER BY oi.id;

-- ============================================================================
-- 3. СХЕМА m6_part: Партиционирование и MATERIALIZED VIEW (Урок 6.2)
-- ============================================================================
CREATE TABLE m6_part.fact_sales_part (
    sale_id      BIGINT GENERATED ALWAYS AS IDENTITY,
    sale_date    DATE NOT NULL,
    city_name    TEXT NOT NULL,
    category     TEXT NOT NULL,
    qty          INT NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (sale_id, sale_date)
) PARTITION BY RANGE (sale_date);

CREATE TABLE m6_part.fact_sales_2026_01
    PARTITION OF m6_part.fact_sales_part
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE m6_part.fact_sales_2026_02
    PARTITION OF m6_part.fact_sales_part
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

CREATE TABLE m6_part.fact_sales_2026_03
    PARTITION OF m6_part.fact_sales_part
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

-- 90 000 строк: ровно по 1 000 строк на каждый из 90 дней (янв 31 000, фев 28 000, мар 31 000)
INSERT INTO m6_part.fact_sales_part (sale_date, city_name, category, qty, total_amount)
SELECT
    DATE '2026-01-01' + ((g - 1) % 90),
    (ARRAY['Алматы', 'Астана', 'Костанай', 'Москва'])[1 + (g % 4)],
    (ARRAY['Электроника', 'Мерч', 'Аксессуары'])[1 + (g % 3)],
    1 + (g % 3),
    (1 + (g % 3)) * (5000 + (g % 5) * 3000)::NUMERIC(10, 2)
FROM generate_series(1, 90000) AS g;

ANALYZE m6_part.fact_sales_part;

-- Материализованная витрина (сначала без UNIQUE INDEX — его создадим в задании 6.2.9)
CREATE MATERIALIZED VIEW m6_part.mv_city_monthly AS
SELECT
    DATE_TRUNC('month', sale_date)::DATE AS month_start,
    city_name,
    category,
    SUM(qty)          AS total_qty,
    SUM(total_amount) AS total_revenue
FROM m6_part.fact_sales_part
GROUP BY DATE_TRUNC('month', sale_date)::DATE, city_name, category
WITH DATA;

CREATE INDEX idx_m6_mv_month ON m6_part.mv_city_monthly (month_start);

-- ============================================================================
-- 4. СХЕМА m6_elt: ELT, идемпотентность, SCD Type 2 и шлюз в ClickHouse (6.4–6.5)
-- ============================================================================
CREATE TABLE m6_elt.raw_orders (
    order_id    INT NOT NULL,
    order_date  DATE NOT NULL,
    customer_bk INT NOT NULL,
    amount      NUMERIC(10, 2) NOT NULL,
    note        TEXT -- NULL = заметки нет
);

CREATE TABLE m6_elt.dwh_orders (
    order_id    INT PRIMARY KEY,
    order_date  DATE NOT NULL,
    customer_bk INT NOT NULL,
    amount      NUMERIC(10, 2) NOT NULL,
    note        TEXT
);

-- Входящий буфер (заказ 102 исправлен с 22 000 на 20 000, добавлен новый заказ 104)
INSERT INTO m6_elt.raw_orders (order_id, order_date, customer_bk, amount, note) VALUES
    (101, '2026-01-10', 1, 35000.00, NULL),
    (102, '2026-01-15', 2, 20000.00, 'Применена скидка 2000'),
    (103, '2026-01-20', 3, 18000.00, NULL),
    (104, '2026-01-25', 1, 15000.00, 'Новый заказ');

-- Текущее состояние целевой таблицы DWH до UPSERT
INSERT INTO m6_elt.dwh_orders (order_id, order_date, customer_bk, amount, note) VALUES
    (101, '2026-01-10', 1, 35000.00, NULL),
    (102, '2026-01-15', 2, 22000.00, NULL),
    (103, '2026-01-20', 3, 18000.00, NULL);

-- Таблица измерения с историей SCD Type 2
CREATE TABLE m6_elt.dim_customer_scd2 (
    customer_sk SERIAL PRIMARY KEY,
    customer_bk INT NOT NULL,
    full_name   TEXT NOT NULL,
    city        TEXT NOT NULL,
    segment     TEXT NOT NULL,
    valid_from  DATE NOT NULL,
    valid_to    DATE NOT NULL DEFAULT DATE '9999-12-31',
    is_current  BOOLEAN NOT NULL DEFAULT true
);

-- Предохранитель: у одного клиента максимум ОДНА активная версия
CREATE UNIQUE INDEX idx_m6_cust_scd2_active
    ON m6_elt.dim_customer_scd2 (customer_bk)
    WHERE is_current = true;

-- Загружена история за Январь и Февраль 2026:
--   bk=1 Айгерим: переехала Костанай -> Алматы с 2026-02-01
--   bk=2 Тимур: вырос Standard -> VIP с 2026-02-01
--   bk=3 Елена: без изменений
--   bk=4 Данияр: появился с 2026-02-01
INSERT INTO m6_elt.dim_customer_scd2
    (customer_bk, full_name, city, segment, valid_from, valid_to, is_current)
VALUES
    (1, 'Айгерим Сатова', 'Костанай', 'VIP',      '2026-01-01', '2026-01-31', false),
    (2, 'Тимур Искаков',  'Астана',   'Standard', '2026-01-01', '2026-01-31', false),
    (3, 'Елена Морозова', 'Алматы',   'VIP',      '2026-01-01', '9999-12-31', true),
    (1, 'Айгерим Сатова', 'Алматы',   'VIP',      '2026-02-01', '9999-12-31', true),
    (2, 'Тимур Искаков',  'Астана',   'VIP',      '2026-02-01', '9999-12-31', true),
    (4, 'Данияр Алимов',  'Костанай', 'Standard', '2026-02-01', '9999-12-31', true);

-- Исторические факты, привязанные через Point-in-Time JOIN к точному customer_sk
CREATE TABLE m6_elt.fact_sales_hist (
    order_id    INT PRIMARY KEY,
    order_date  DATE NOT NULL,
    customer_sk INT NOT NULL REFERENCES m6_elt.dim_customer_scd2(customer_sk),
    amount      NUMERIC(10, 2) NOT NULL
);

INSERT INTO m6_elt.fact_sales_hist (order_id, order_date, customer_sk, amount) VALUES
    (201, '2026-01-12', 1, 35000.00), -- Айгерим ещё в Костанае (sk=1)
    (202, '2026-01-20', 2, 15000.00), -- Тимур ещё Standard (sk=2)
    (203, '2026-02-05', 4, 22000.00), -- Айгерим уже в Алматы (sk=4)
    (204, '2026-02-14', 5, 40000.00), -- Тимур уже VIP (sk=5)
    (205, '2026-02-18', 3, 18000.00); -- Елена в Алматы (sk=3)

-- Входящий снимок клиентов на 1 марта 2026 (для задания 6.4.9 по обновлению SCD2)
CREATE TABLE m6_elt.raw_customers_stage (
    customer_bk INT PRIMARY KEY,
    full_name   TEXT NOT NULL,
    city        TEXT NOT NULL,
    segment     TEXT NOT NULL
);

INSERT INTO m6_elt.raw_customers_stage (customer_bk, full_name, city, segment) VALUES
    (1, 'Айгерим Сатова', 'Алматы',  'VIP'),      -- без изменений
    (2, 'Тимур Искаков',  'Астана',  'VIP'),      -- без изменений
    (3, 'Елена Морозова', 'Алматы',  'VIP'),      -- без изменений
    (4, 'Данияр Алимов',  'Астана',  'Standard'), -- переехал Костанай -> Астана!
    (5, 'София Ким',      'Шымкент', 'Standard'); -- новый клиент!

-- Плоская экспортная витрина-шлюз, которую ClickHouse читает напрямую по сети db_net (Урок 6.5)
CREATE TABLE m6_elt.export_sales_mart (
    item_bk       INT PRIMARY KEY,
    order_bk      INT NOT NULL,
    order_date    DATE NOT NULL,
    customer_bk   INT NOT NULL,
    city_name     TEXT NOT NULL,
    segment       TEXT NOT NULL,
    product_title TEXT NOT NULL,
    category_name TEXT NOT NULL,
    qty           INT NOT NULL,
    total_amount  NUMERIC(12, 2) NOT NULL
);

-- 6 оплаченных позиций (январь: 89 000.00, февраль: 63 000.00, итого: 152 000.00)
INSERT INTO m6_elt.export_sales_mart VALUES
    (1, 1001, '2026-01-12', 1, 'Костанай', 'Standard', 'Механическая клавиатура', 'Электроника', 1, 33000.00),
    (2, 1001, '2026-01-12', 1, 'Костанай', 'Standard', 'Термокружка кодера',      'Аксессуары',  2, 16000.00),
    (3, 1002, '2026-01-18', 2, 'Алматы',   'VIP',      'Худи «SQL Master»',       'Мерч',        2, 40000.00),
    (5, 1004, '2026-02-08', 1, 'Алматы',   'VIP',      'Худи «SQL Master»',       'Мерч',        1, 20000.00),
    (6, 1005, '2026-02-14', 4, 'Астана',   'Standard', 'Механическая клавиатура', 'Электроника', 1, 35000.00),
    (7, 1005, '2026-02-14', 4, 'Астана',   'Standard', 'Термокружка кодера',      'Аксессуары',  1,  8000.00);

-- ============================================================================
-- Итоговая сводка загруженных строк по таблицам PostgreSQL
-- ============================================================================
SELECT 'm6_oltp.orders'           AS table_name, COUNT(*) AS rows_count FROM m6_oltp.orders
UNION ALL
SELECT 'm6_oltp.order_items',      COUNT(*) FROM m6_oltp.order_items
UNION ALL
SELECT 'm6_star.dim_date',         COUNT(*) FROM m6_star.dim_date
UNION ALL
SELECT 'm6_star.dim_product',      COUNT(*) FROM m6_star.dim_product
UNION ALL
SELECT 'm6_star.dim_customer',     COUNT(*) FROM m6_star.dim_customer
UNION ALL
SELECT 'm6_star.fact_sales',       COUNT(*) FROM m6_star.fact_sales
UNION ALL
SELECT 'm6_part.fact_sales_part',  COUNT(*) FROM m6_part.fact_sales_part
UNION ALL
SELECT 'm6_part.mv_city_monthly',  COUNT(*) FROM m6_part.mv_city_monthly
UNION ALL
SELECT 'm6_elt.raw_orders',        COUNT(*) FROM m6_elt.raw_orders
UNION ALL
SELECT 'm6_elt.dwh_orders',        COUNT(*) FROM m6_elt.dwh_orders
UNION ALL
SELECT 'm6_elt.dim_customer_scd2', COUNT(*) FROM m6_elt.dim_customer_scd2
UNION ALL
SELECT 'm6_elt.fact_sales_hist',   COUNT(*) FROM m6_elt.fact_sales_hist
UNION ALL
SELECT 'm6_elt.export_sales_mart', COUNT(*) FROM m6_elt.export_sales_mart;
