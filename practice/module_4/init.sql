-- ============================================================================
-- МОДУЛЬ 4 (PostgreSQL 16): Подготовка учебной базы данных
-- ============================================================================
-- Этот скрипт создаёт 6 учебных таблиц в базе learning_db и наполняет их
-- стартовыми данными для практики по Урокам 4.1–4.4:
--   - wallets, transfer_log, shop_items — транзакции, ACID, SAVEPOINT, аномалии, HOT
--   - mvcc_lab (10 000 строк, autovacuum off) — MVCC, Bloat, VACUUM, Index-Only Scan
--   - ticket_queue — строчные блокировки FOR UPDATE / NOWAIT / SKIP LOCKED
--   - parking_slots — проверка Heap-порядка, отсутствия Gap Locks и транзакционного DDL
--
-- Скрипт идемпотентен: его можно запускать повторно в любой момент для полного
-- сброса таблиц и данных в исходное состояние.
--
-- Как запустить из терминала (из корневой папки курса):
--   Linux / macOS / Git Bash:
--     docker exec -i course_pg_primary psql -U student -d learning_db < practice/module_4/init.sql
--
--   Windows PowerShell:
--     Get-Content practice/module_4/init.sql -Raw | docker exec -i course_pg_primary psql -U student -d learning_db
--
-- Либо открой этот файл в DBeaver / DataGrip / Adminer и выполни целиком.
-- ============================================================================

-- 1. Удаляем старые таблицы в правильном порядке (сначала зависимые)
DROP TABLE IF EXISTS transfer_log CASCADE;
DROP TABLE IF EXISTS ticket_queue CASCADE;
DROP TABLE IF EXISTS wallets CASCADE;
DROP TABLE IF EXISTS shop_items CASCADE;
DROP TABLE IF EXISTS mvcc_lab CASCADE;
DROP TABLE IF EXISTS parking_slots CASCADE;

-- 2. Таблица кошельков игроков (транзакции, CHECK, Deadlock, Write Skew)
CREATE TABLE wallets (
    id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner   TEXT NOT NULL UNIQUE,
    balance NUMERIC(10, 2) NOT NULL CHECK (balance >= 0),
    city    TEXT NOT NULL,
    is_vip  BOOLEAN NOT NULL DEFAULT false
);

-- 3. Журнал переводов между кошельками (Consistency: нельзя перевести самому себе)
CREATE TABLE transfer_log (
    id             INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    from_wallet_id INT NOT NULL REFERENCES wallets(id) ON DELETE RESTRICT,
    to_wallet_id   INT NOT NULL REFERENCES wallets(id) ON DELETE RESTRICT,
    amount         NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    note           TEXT, -- NULL = перевод без комментария
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (from_wallet_id <> to_wallet_id)
);

-- 4. Очередь билетов (строчные блокировки: FOR UPDATE, NOWAIT, SKIP LOCKED)
CREATE TABLE ticket_queue (
    id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seat      TEXT NOT NULL UNIQUE,
    status    TEXT NOT NULL DEFAULT 'free'
              CHECK (status IN ('free', 'reserved', 'paid')),
    wallet_id INT REFERENCES wallets(id) ON DELETE SET NULL -- NULL = место свободно
);

-- 5. Игровая лавка (аномалии чтения, CHECK stock >= 0, HOT-обновления)
CREATE TABLE shop_items (
    id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title TEXT NOT NULL UNIQUE,
    price NUMERIC(10, 2) NOT NULL CHECK (price > 0),
    stock INT NOT NULL CHECK (stock >= 0),
    views INT NOT NULL DEFAULT 0 -- НЕ индексируется: идеально для HOT-обновлений
);

-- Вторичный индекс по цене (обновление price НЕ может быть HOT, а обновление views — может!)
CREATE INDEX idx_shop_items_price ON shop_items (price);

-- 6. Лаборатория MVCC и VACUUM (10 000 строк, автоуборка выключена только для опытов!)
CREATE TABLE mvcc_lab (
    id      INT PRIMARY KEY,
    status  TEXT NOT NULL DEFAULT 'active',
    counter INT NOT NULL DEFAULT 0,
    payload TEXT NOT NULL
) WITH (autovacuum_enabled = false);

-- 7. Парковочные слоты с «дырками» (Heap-порядок, отсутствие Gap Locks, транзакционный DDL)
CREATE TABLE parking_slots (
    id         INT PRIMARY KEY,
    car        TEXT NOT NULL,
    owner_name TEXT -- NULL = служебная машина без владельца
);

-- ============================================================================
-- Наполняем таблицы стартовыми данными
-- ============================================================================

INSERT INTO wallets (owner, balance, city, is_vip) VALUES
    ('Алиса', 1000.00, 'Алматы',    true),  -- id = 1, VIP
    ('Боб',    500.00, 'Астана',    false), -- id = 2
    ('Чарли',  200.00, 'Алматы',    false), -- id = 3
    ('Дина',   750.00, 'Шымкент',   true),  -- id = 4, VIP (сумма VIP = 1750.00)
    ('Егор',     0.00, 'Караганда', false); -- id = 5, нулевой баланс

INSERT INTO transfer_log (from_wallet_id, to_wallet_id, amount, note, created_at) VALUES
    (1, 2, 150.00, 'За экипировку',    '2026-11-20 10:00:00+05'),
    (4, 3, 100.00, 'Подарок на старт', '2026-11-21 14:30:00+05'),
    (2, 1,  50.00, NULL,               '2026-11-22 18:15:00+05'), -- без комментария
    (1, 4, 200.00, 'Возврат долга',    '2026-11-23 09:45:00+05');

INSERT INTO ticket_queue (seat, status, wallet_id) VALUES
    ('Ряд 1, Место 1', 'free',     NULL), -- id = 1
    ('Ряд 1, Место 2', 'free',     NULL), -- id = 2
    ('Ряд 1, Место 3', 'free',     NULL), -- id = 3
    ('Ряд 1, Место 4', 'free',     NULL), -- id = 4
    ('Ряд 2, Место 1', 'reserved', 1),    -- id = 5 (Алиса)
    ('Ряд 2, Место 2', 'paid',     4);    -- id = 6 (Дина)

INSERT INTO shop_items (title, price, stock, views) VALUES
    ('Алмазный меч',    600.00, 2, 120), -- id = 1
    ('Зелье маны',      150.00, 5,  85), -- id = 2
    ('Щит новичка',     300.00, 1,  40), -- id = 3 (осталась 1 штука!)
    ('Плащ невидимки',  450.00, 0, 210), -- id = 4 (нет на складе: stock = 0)
    ('Компас героя',    120.00, 8,  30), -- id = 5
    ('Сапоги скорости', 800.00, 3,  65); -- id = 6

-- 10 000 строк для экспериментов с Table Bloat, VACUUM и Index-Only Scan
-- 8 000 со статусом 'active' и 2 000 со статусом 'archived'
INSERT INTO mvcc_lab (id, status, counter, payload)
SELECT
    g,
    CASE WHEN g % 5 = 0 THEN 'archived' ELSE 'active' END,
    0,
    repeat('x', 80)
FROM generate_series(1, 10000) AS g;

-- Вставляем id намеренно НЕ по порядку и с «дырками» (20, 40, 60)
INSERT INTO parking_slots (id, car, owner_name) VALUES
    (50, 'Кроссовер', 'Дина'),
    (10, 'Седан',     'Алиса'),
    (30, 'Джип',      'Боб'),
    (70, 'Фургон',    NULL);

-- Обновляем статистику планировщика (без VACUUM, чтобы Visibility Map заполнить вручную в 4.4)
ANALYZE wallets;
ANALYZE transfer_log;
ANALYZE ticket_queue;
ANALYZE shop_items;
ANALYZE mvcc_lab;
ANALYZE parking_slots;

-- Быстрая проверка, что всё загрузилось:
SELECT 'wallets' AS table_name, COUNT(*) AS rows_count FROM wallets
UNION ALL
SELECT 'transfer_log',  COUNT(*) FROM transfer_log
UNION ALL
SELECT 'ticket_queue',  COUNT(*) FROM ticket_queue
UNION ALL
SELECT 'shop_items',    COUNT(*) FROM shop_items
UNION ALL
SELECT 'mvcc_lab',      COUNT(*) FROM mvcc_lab
UNION ALL
SELECT 'parking_slots', COUNT(*) FROM parking_slots;
