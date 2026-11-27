-- ============================================================================
-- МОДУЛЬ 4 (MySQL 8.4 / InnoDB): Подготовка базы для Урока 4.4 (Дуэль СУБД)
-- ============================================================================
-- Этот скрипт создаёт 2 компактные таблицы на движке InnoDB в базе learning_db
-- контейнера course_mysql_innodb (профиль --profile mod4), чтобы сравнивать
-- поведение MySQL/InnoDB с PostgreSQL 16 бок о бок:
--   - parking_slots — Clustered Index (сортировка по PK) и Gap Locks
--   - duel_accounts — уровень REPEATABLE READ, ON DUPLICATE KEY UPDATE и неявный COMMIT при DDL
--
-- Скрипт идемпотентен: запускай его повторно для сброса таблиц в исходное состояние.
--
-- Как запустить из терминала (из корневой папки курса):
--   Сначала подними профиль mod4:
--     docker compose --profile mod4 up -d
--
--   Linux / macOS / Git Bash:
--     docker exec -i course_mysql_innodb mysql -u student -pstudent_pass learning_db < practice/module_4/init_mysql.sql
--
--   Windows PowerShell:
--     Get-Content practice/module_4/init_mysql.sql -Raw | docker exec -i course_mysql_innodb mysql -u student -pstudent_pass learning_db
-- ============================================================================

SET NAMES utf8mb4;

DROP TABLE IF EXISTS parking_slots;
DROP TABLE IF EXISTS duel_accounts;

-- 1. Парковочные слоты: вставляем id вразнобой (50, 10, 30, 70), но InnoDB
--    физически упорядочит их в кластерном индексе PRIMARY KEY (10 -> 30 -> 50 -> 70)!
CREATE TABLE parking_slots (
    id         INT PRIMARY KEY,
    car        VARCHAR(100) NOT NULL,
    owner_name VARCHAR(100) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. Счета для сравнения диалекта MySQL (AUTO_INCREMENT, ON DUPLICATE KEY) и неявного COMMIT DDL
CREATE TABLE duel_accounts (
    id      INT AUTO_INCREMENT PRIMARY KEY,
    owner   VARCHAR(100) NOT NULL UNIQUE,
    balance DECIMAL(10, 2) NOT NULL CHECK (balance >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Вставляем id в ТОЧНО таком же перепутанном порядке, как в PostgreSQL!
INSERT INTO parking_slots (id, car, owner_name) VALUES
    (50, 'Кроссовер', 'Дина'),
    (10, 'Седан',     'Алиса'),
    (30, 'Джип',      'Боб'),
    (70, 'Фургон',    NULL);

INSERT INTO duel_accounts (owner, balance) VALUES
    ('Алиса', 1000.00),
    ('Боб',    500.00),
    ('Чарли',  200.00);

-- Быстрая проверка загруженных строк:
SELECT 'parking_slots' AS table_name, COUNT(*) AS rows_count FROM parking_slots
UNION ALL
SELECT 'duel_accounts', COUNT(*) FROM duel_accounts;
