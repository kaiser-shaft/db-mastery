-- ============================================================================
-- МОДУЛЬ 1: Подготовка учебной базы данных (онлайн-магазин IT-мерча)
-- ============================================================================
-- Этот скрипт создаёт 4 связанные таблицы в базе learning_db и наполняет их
-- стартовыми данными для практики по Урокам 1.1–1.4.
--
-- Скрипт можно запускать повторно в любой момент — он безопасно пересоздаст
-- таблицы и вернёт данные в исходное состояние (удобно после UPDATE/DELETE).
--
-- Как запустить из терминала (из корневой папки курса):
--   Linux / macOS / Git Bash:
--     docker exec -i course_pg_primary psql -U student -d learning_db < practice/module_1/init.sql
--
--   Windows PowerShell:
--     Get-Content practice/module_1/init.sql -Raw | docker exec -i course_pg_primary psql -U student -d learning_db
--
-- Либо просто открой этот файл в DBeaver / DataGrip / Adminer и выполни целиком.
-- ============================================================================

-- 1. Удаляем старые таблицы в правильном порядке (сначала зависимые)
DROP TABLE IF EXISTS product_reviews CASCADE;
DROP TABLE IF EXISTS promo_codes CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

-- 2. Таблица категорий товаров
CREATE TABLE categories (
    id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name    TEXT NOT NULL UNIQUE,
    manager TEXT NOT NULL
);

-- 3. Таблица покупателей
CREATE TABLE customers (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name  TEXT NOT NULL,
    email      TEXT NOT NULL UNIQUE,
    city       TEXT NOT NULL,
    age        INT CHECK (age >= 12 AND age <= 120), -- NULL = возраст не указан
    is_active  BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Таблица товаров
CREATE TABLE products (
    id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title        TEXT NOT NULL UNIQUE,
    category_id  INT REFERENCES categories(id) ON DELETE RESTRICT, -- NULL = черновик без категории
    price        NUMERIC(10, 2) NOT NULL CHECK (price > 0),
    discount_pct INT CHECK (discount_pct BETWEEN 0 AND 90),        -- NULL = скидка не задана
    stock        INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    rating       NUMERIC(2, 1) CHECK (rating BETWEEN 1.0 AND 5.0), -- NULL = отзывов ещё нет
    is_active    BOOLEAN NOT NULL DEFAULT true
);

-- 5. Таблица заказов
CREATE TABLE orders (
    id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    product_id  INT NOT NULL REFERENCES products(id)  ON DELETE RESTRICT,
    quantity    INT NOT NULL CHECK (quantity > 0),
    status      TEXT NOT NULL DEFAULT 'new'
                CHECK (status IN ('new', 'paid', 'shipped', 'cancelled')),
    ordered_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- Наполняем таблицы данными
-- ============================================================================

INSERT INTO categories (name, manager) VALUES
    ('Одежда',          'Алина'),
    ('Аксессуары',      'Тимур'),
    ('Книги',           'Алина'),
    ('Гаджеты',         'Даниил'),
    ('Настольные игры', 'Тимур'); -- пустая категория (пока без товаров)

INSERT INTO customers (full_name, email, city, age, is_active) VALUES
    ('Артём Смирнов',   'artem@school.kz', 'Алматы',    16,   true),
    ('Алина Нурланова', 'alina@school.kz', 'Астана',    15,   true),
    ('Максим Волков',   'max@school.kz',   'Алматы',    17,   true),
    ('Дина Касымова',   'dina@school.kz',  'Шымкент',   NULL, true),  -- без возраста и без заказов
    ('София Ким',       'sofia@school.kz', 'Алматы',    16,   true),
    ('Тимур Алиев',     'timur@school.kz', 'Астана',    18,   false), -- неактивный аккаунт
    ('Егор Морозов',    'egor@school.kz',  'Караганда', NULL, true);  -- без возраста

INSERT INTO products (title, category_id, price, discount_pct, stock, rating, is_active) VALUES
    ('Худи «SQL Master»',         1,    14500.00, 10,   12,  4.9, true),
    ('Футболка «SELECT *»',       1,     5900.00,  0,   25,  4.7, true),
    ('Стикерпак «Postgres»',      2,     1200.00, NULL, 100, 4.8, true),
    ('Термокружка кодера',        2,     6900.00, 15,    8,  4.6, true),
    ('Книга «SQL за 7 дней»',     3,     4200.00, NULL, 14,  4.9, true),
    ('Коврик для мыши XL',        2,     3500.00,  5,    0,  4.4, true), -- нет в наличии (stock = 0)
    ('Клавиатура «MechPro»',      4,    18900.00, 20,    3,  4.9, true),
    ('Кепка «NULL Safety»',       1,     3900.00, NULL, 19,  NULL, true), -- нет рейтинга и скидки
    ('USB-хаб «Docker Port»',     4,     7400.00,  0,    6,  4.5, true),
    ('Блокнот архитектора',       3,     2100.00, NULL, 30,  NULL, true), -- нет рейтинга и скидки
    ('Секретный мерч (черновик)', NULL,   990.00, NULL,  0,  NULL, false), -- черновик без категории
    ('Тестовый баг-товар',        2,      100.00,  0,    0,  NULL, false); -- мусорная запись для DELETE

INSERT INTO orders (customer_id, product_id, quantity, status, ordered_at) VALUES
    (1,  1, 1, 'paid',      '2026-11-10 10:15:00+05'), -- Артём: 1 Худи
    (2,  3, 3, 'paid',      '2026-11-11 14:30:00+05'), -- Алина: 3 Стикерпака
    (1,  4, 1, 'shipped',   '2026-11-12 09:00:00+05'), -- Артём: 1 Термокружка
    (3,  7, 1, 'new',       '2026-11-14 18:45:00+05'), -- Максим: 1 Клавиатура
    (5,  5, 2, 'paid',      '2026-11-15 12:20:00+05'), -- София: 2 Книги
    (5,  2, 1, 'shipped',   '2026-11-16 16:05:00+05'), -- София: 1 Футболка
    (3,  9, 2, 'cancelled', '2026-11-17 11:10:00+05'), -- Максим: отменил 2 USB-хаба
    (7, 10, 4, 'new',       '2026-11-18 19:00:00+05'); -- Егор: 4 Блокнота

-- Быстрая проверка, что всё загрузилось:
SELECT 'categories' AS table_name, COUNT(*) AS rows_count FROM categories
UNION ALL
SELECT 'customers',  COUNT(*) FROM customers
UNION ALL
SELECT 'products',   COUNT(*) FROM products
UNION ALL
SELECT 'orders',     COUNT(*) FROM orders;
