-- ============================================================================
-- МОДУЛЬ 2: Подготовка учебной базы данных (онлайн-магазин в 3НФ + JSONB)
-- ============================================================================
-- Этот скрипт создаёт 6 связанных таблиц в базе learning_db и наполняет их
-- стартовыми данными для практики по Урокам 2.1–2.5:
--   cities, customers, products, orders, order_items, newsletter_leads.
--
-- Скрипт можно запускать повторно в любой момент — он безопасно пересоздаст
-- таблицы (включая вспомогательные таблицы из заданий Урока 2.1) и вернёт
-- базу в исходное состояние.
--
-- Как запустить из терминала (из корневой папки курса):
--   Linux / macOS / Git Bash:
--     docker exec -i course_pg_primary psql -U student -d learning_db < practice/module_2/init.sql
--
--   Windows PowerShell:
--     Get-Content practice/module_2/init.sql -Raw | docker exec -i course_pg_primary psql -U student -d learning_db
--
-- Либо просто открой этот файл в DBeaver / DataGrip / Adminer и выполни целиком.
-- ============================================================================

-- 1. Удаляем старые и вспомогательные таблицы в правильном порядке
DROP TABLE IF EXISTS product_tags CASCADE;
DROP TABLE IF EXISTS tags CASCADE;
DROP TABLE IF EXISTS schema_migrations CASCADE;
DROP TABLE IF EXISTS bad_orders_sheet CASCADE;
DROP TABLE IF EXISTS student_clubs CASCADE;
DROP TABLE IF EXISTS clubs CASCADE;
DROP TABLE IF EXISTS club_students CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS cities CASCADE;
DROP TABLE IF EXISTS newsletter_leads CASCADE;

-- 2. Справочник городов (3НФ: часовой пояс зависит от города, а не от клиента)
CREATE TABLE cities (
    id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name     TEXT NOT NULL UNIQUE,
    timezone TEXT NOT NULL
);

-- 3. Таблица покупателей (с «грязными» строками и одним NULL в city_id)
CREATE TABLE customers (
    id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name     TEXT NOT NULL,
    email         TEXT NOT NULL UNIQUE,
    city_id       INT REFERENCES cities(id) ON DELETE RESTRICT, -- NULL = город не указан
    registered_at TIMESTAMPTZ NOT NULL
);

-- 4. Каталог товаров (строгие поля + гибкий JSONB specs + равные цены для рейтингов)
CREATE TABLE products (
    id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title    TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL,
    price    NUMERIC(10, 2) NOT NULL CHECK (price > 0),
    specs    JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- 5. Таблица заказов (даты за 4 месяца + вложенный JSONB delivery_info)
CREATE TABLE orders (
    id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id   INT NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    status        TEXT NOT NULL CHECK (status IN ('paid', 'cancelled', 'pending')),
    created_at    TIMESTAMPTZ NOT NULL,
    delivery_info JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- 6. Состав заказов (связь M:N между orders и products, составной PRIMARY KEY)
CREATE TABLE order_items (
    order_id   INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity   INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    PRIMARY KEY (order_id, product_id)
);

-- 7. Подписчики рассылки с лендинга (для задач на UNION / UNION ALL)
CREATE TABLE newsletter_leads (
    id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name TEXT NOT NULL,
    email     TEXT NOT NULL UNIQUE
);

-- ============================================================================
-- Наполняем таблицы данными
-- ============================================================================

INSERT INTO cities (name, timezone) VALUES
    ('Алматы',    'UTC+5'), -- id = 1
    ('Астана',    'UTC+5'), -- id = 2
    ('Шымкент',   'UTC+5'), -- id = 3
    ('Караганда', 'UTC+5'); -- id = 4 (пустой город: пока нет клиентов)

INSERT INTO customers (full_name, email, city_id, registered_at) VALUES
    ('  алексей иванов  ', 'Alex.Ivanov@Mail.KZ',   1,    '2025-11-05 10:00:00+05'), -- id = 1 (пробелы + разный регистр)
    ('Мария Смирнова',     'maria@company.org',     2,    '2025-11-20 14:15:00+05'), -- id = 2 (есть в newsletter_leads)
    ('Тимур Касымов',      'timur.k@gmail.com',     3,    '2025-12-12 09:30:00+05'), -- id = 3 (есть в newsletter_leads)
    ('Елена Волкова',      'ELENA.VOLKOVA@Shop.KZ', 1,    '2026-01-08 16:45:00+05'), -- id = 4 (заглавный email)
    ('Данияр Нурланов',    'daniyar@tech.kz',       NULL, '2026-02-01 12:00:00+05'), -- id = 5 (город NULL, 0 заказов)
    ('Ольга Ким',          'olga.kim@mail.kz',      2,    '2026-02-15 11:10:00+05'), -- id = 6 (только отменённый заказ)
    ('  дина алиева',      'dina.alieva@gmail.com', 1,    '2026-03-01 09:00:00+05'); -- id = 7 (пробелы в начале, paid + pending)

INSERT INTO products (title, category, price, specs) VALUES
    ('Механическая клавиатура', 'Гаджеты',    39000.00, '{"brand": "KeyPro", "color": "white", "weight_g": 820, "tags": ["hit", "pro"]}'),            -- id = 1
    ('Беспроводная мышь',       'Гаджеты',    18000.00, '{"brand": "KeyPro", "color": "black", "weight_g": 95, "tags": ["pro"]}'),                    -- id = 2
    ('Коврик для мыши XL',      'Гаджеты',     9000.00, '{"color": "dark-gray", "width_cm": 90, "waterproof": true, "tags": ["pro"]}'),               -- id = 3 (ничья 9000)
    ('Худи «SQL Master»',       'Мерч',       15000.00, '{"color": "black", "size": "L", "material": "cotton", "tags": ["hit", "winter"]}'),          -- id = 4
    ('Свитшот «PostgreSQL»',    'Мерч',       12000.00, '{"color": "navy", "size": "M", "material": "cotton", "tags": ["winter"]}'),                  -- id = 5
    ('Футболка «SELECT *»',     'Мерч',        9000.00, '{"color": "white", "size": "M", "material": "cotton", "tags": ["summer"]}'),                 -- id = 6 (ничья 9000)
    ('Термокружка кодера',      'Аксессуары',  6000.00, '{"color": "black", "volume_ml": 450, "waterproof": true, "tags": ["hit", "gift"]}'),         -- id = 7 (ничья 6000)
    ('Кепка «PG 16»',           'Аксессуары',  6000.00, '{"color": "blue", "size": "one-size", "tags": ["gift"]}'),                                   -- id = 8 (ничья 6000)
    ('Стикерпак «Postgres»',    'Аксессуары',  2000.00, '{"color": "blue", "pcs": 12, "waterproof": true, "tags": ["gift"]}'),                        -- id = 9
    ('Брелок «Слон Postgres»',  'Аксессуары',  1500.00, '{"tags": ["gift"]}');                                                                        -- id = 10 (нет color, 0 продаж)

INSERT INTO orders (customer_id, status, created_at, delivery_info) VALUES
    (1, 'paid',      '2026-01-10 10:00:00+05', '{"courier": "FastBox", "express": true,  "address": {"city": "Алматы",  "street": "Абая 15"}}'),      -- id = 1
    (2, 'paid',      '2026-01-22 14:30:00+05', '{"courier": "PostKZ",  "express": false, "address": {"city": "Астана",  "street": "Достык 8"}}'),     -- id = 2
    (1, 'paid',      '2026-02-05 12:00:00+05', '{"courier": "FastBox", "express": true,  "address": {"city": "Алматы",  "street": "Абая 15"}}'),      -- id = 3
    (3, 'cancelled', '2026-02-10 18:00:00+05', '{"courier": "PostKZ",  "express": false, "address": {"city": "Шымкент", "street": "Тауке Хана 7"}}'), -- id = 4
    (4, 'paid',      '2026-02-18 11:15:00+05', '{"courier": "FastBox", "express": false, "address": {"city": "Алматы",  "street": "Сатпаева 30"}}'),  -- id = 5
    (6, 'cancelled', '2026-02-18 19:00:00+05', '{"courier": "PostKZ",  "express": false, "address": {"city": "Астана",  "street": "Мангилик Ел 12"}}'),-- id = 6
    (2, 'paid',      '2026-03-04 16:00:00+05', '{"courier": "FastBox", "express": true,  "address": {"city": "Астана",  "street": "Достык 8"}}'),     -- id = 7
    (1, 'paid',      '2026-03-20 09:45:00+05', '{"courier": "FastBox", "express": true,  "address": {"city": "Алматы",  "street": "Абая 15"}}'),      -- id = 8  (одна дата с №9!)
    (7, 'paid',      '2026-03-20 15:20:00+05', '{"courier": "PostKZ",  "express": false, "address": {"city": "Алматы",  "street": "Достык 40"}}'),    -- id = 9  (одна дата с №8!)
    (3, 'paid',      '2026-04-02 15:00:00+05', '{"courier": "PostKZ",  "express": false, "address": {"city": "Шымкент", "street": "Тауке Хана 7"}}'), -- id = 10
    (4, 'paid',      '2026-04-15 13:20:00+05', '{"courier": "FastBox", "express": true,  "address": {"city": "Алматы",  "street": "Сатпаева 30"}}'),  -- id = 11
    (7, 'pending',   '2026-04-20 17:10:00+05', '{"courier": "FastBox", "express": false, "address": {"city": "Алматы",  "street": "Достык 40"}}');    -- id = 12

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (1,  4, 1, 15000.00), (1,  9, 2,  2000.00), -- заказ 1:  19 000 (paid)
    (2,  2, 1, 18000.00), (2,  7, 2,  6000.00), -- заказ 2:  30 000 (paid) -> январь = 49 000
    (3,  1, 1, 39000.00),                       -- заказ 3:  39 000 (paid)
    (4,  5, 1, 12000.00),                       -- заказ 4:  12 000 (cancelled)
    (5,  4, 1, 15000.00), (5,  8, 1,  6000.00), -- заказ 5:  21 000 (paid) -> февраль = 60 000
    (6,  1, 1, 39000.00),                       -- заказ 6:  39 000 (cancelled)
    (7,  5, 1, 12000.00), (7,  7, 2,  6000.00), -- заказ 7:  24 000 (paid)
    (8,  6, 1,  9000.00), (8,  3, 1,  9000.00), -- заказ 8:  18 000 (paid)
    (9,  7, 1,  6000.00), (9,  9, 3,  2000.00), -- заказ 9:  12 000 (paid) -> март = 54 000
    (10, 1, 1, 39000.00), (10, 2, 1, 18000.00), -- заказ 10: 57 000 (paid)
    (11, 5, 1, 12000.00),                       -- заказ 11: 12 000 (paid) -> апрель = 69 000
    (12, 6, 2,  9000.00);                       -- заказ 12: 18 000 (pending)

INSERT INTO newsletter_leads (full_name, email) VALUES
    ('Мария Смирнова', 'maria@company.org'), -- совпадает с customers (id=2)
    ('Егор Савин',     'egor@mail.kz'),      -- новый подписчик
    ('Жанна Нур',      'zhanna@gmail.com'),  -- новый подписчик
    ('Тимур Касымов',  'timur.k@gmail.com'); -- совпадает с customers (id=3)

-- Быстрая проверка, что всё загрузилось:
SELECT 'cities'           AS table_name, COUNT(*) AS rows_count FROM cities
UNION ALL
SELECT 'customers',        COUNT(*) FROM customers
UNION ALL
SELECT 'products',         COUNT(*) FROM products
UNION ALL
SELECT 'orders',           COUNT(*) FROM orders
UNION ALL
SELECT 'order_items',      COUNT(*) FROM order_items
UNION ALL
SELECT 'newsletter_leads', COUNT(*) FROM newsletter_leads;
