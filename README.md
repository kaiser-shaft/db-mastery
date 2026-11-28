# db-mastery

Практический офлайн-курс по базам данных: **6 модулей, 26 уроков**, презентации, практикумы и Docker-стенд (`PostgreSQL 16`, `MySQL 8.4`, `ClickHouse`, `PgBouncer`, `Adminer`). Работает прямо в браузере без интернета и сборки.

**Точки входа:** [`index.html`](index.html) (оглавление и прогресс) · [`handout.html`](handout.html) (шпаргалка) · [`docker_guide.html`](docker_guide.html) (гид по стенду)  
**Навигация:** [Старт за 30 секунд](#старт-за-30-секунд) · [Модули и стенд](#модули-и-стенд) · [Подключения и порты](#подключения-и-порты) · [Команды стенда](#команды-стенда) · [Все уроки и структура](#справочник-файлов)

## Старт за 30 секунд

Требуется **Docker Compose v2** и любой браузер.

```bash
git clone https://github.com/kaiser-shaft/db-mastery.git
cd db-mastery

# Поднять базовый PostgreSQL 16 (нужен для всех модулей)
docker compose up -d

# Проверить статус и зайти в psql
docker compose ps
docker exec -it course_pg_primary psql -U student -d learning_db
```

После запуска откройте [`index.html`](index.html) в браузере. При необходимости подключите веб-клиент Adminer: `docker compose --profile ui up -d` → [localhost:8080](http://localhost:8080).

## Модули и стенд

| # | Тема | Уроки | Материалы | Профиль Docker | Инициализация практики |
| :---: | --- | :---: | --- | --- | --- |
| **1** | Фундамент реляционных БД и базовый SQL | 1.1–1.4 | [Слайды](slides/module-1.html) · [Практика](practice/module_1/practice.html) | *(базовый)* | [`module_1/init.sql`](practice/module_1/init.sql) |
| **2** | Проектирование схем и продвинутый SQL | 2.1–2.5 | [Слайды](slides/module-2.html) · [Практика](practice/module_2/practice.html) | *(базовый)* | [`module_2/init.sql`](practice/module_2/init.sql) |
| **3** | Внутреннее устройство PostgreSQL: страницы, индексы, WAL | 3.1–3.4 | [Слайды](slides/module-3.html) · [Практика](practice/module_3/practice.html) | *(базовый)* | [`module_3/init.sql`](practice/module_3/init.sql) |
| **4** | Транзакции, MVCC, блокировки и MySQL/InnoDB | 4.1–4.4 | [Слайды](slides/module-4.html) · [Практика](practice/module_4/practice.html) | `--profile mod4` | [`init.sql`](practice/module_4/init.sql) · [`init_mysql.sql`](practice/module_4/init_mysql.sql) |
| **5** | Репликация, бэкапы (PITR) и PgBouncer | 5.1–5.4 | [Слайды](slides/module-5.html) · [Практика](practice/module_5/practice.html) | `--profile mod5` | [`module_5/init.sql`](practice/module_5/init.sql) |
| **6** | Архитектура DWH, ClickHouse и итоговый проект | 6.1–6.5 | [Слайды](slides/module-6.html) · [Практика](practice/module_6/practice.html) | `--profile mod6` | [`init.sql`](practice/module_6/init.sql) · [`init_clickhouse.sql`](practice/module_6/init_clickhouse.sql) |

> [!NOTE]
> **Для урока 5.4 (PITR):** в [`docker-compose.yaml`](docker-compose.yaml) у сервиса `pg_primary` закомментированы `archive_mode` и `archive_command` (архивация WAL в `./backups/wal`). Раскомментируйте эти строки и выполните `docker compose up -d pg_primary`.

## Подключения и порты

Основная строка подключения PostgreSQL:

```text
postgresql://student:student_pass@localhost:5432/learning_db
```

| Сервис | Контейнер | Профиль | Порт | База и креды |
| --- | --- | --- | :---: | --- |
| **PostgreSQL 16 Primary** | `course_pg_primary` | по умолчанию | `5432` | `learning_db` · `student` / `student_pass` |
| **MySQL 8.4 (InnoDB)** | `course_mysql_innodb` | `mod4`, `all` | `3306` | `learning_db` · `student` / `student_pass` (`root` / `root_pass`) |
| **PostgreSQL 16 Standby** | `course_pg_standby` | `mod5`, `all` | `5433` | физическая реплика `pg_primary` |
| **PostgreSQL 16 Logical** | `course_pg_logical` | `mod5`, `all` | `5434` | `learning_db` · `student` / `student_pass` |
| **PgBouncer** | `course_pgbouncer` | `mod5`, `all` | `6432` | `learning_db` · `student` / `student_pass` (`transaction` pool) |
| **ClickHouse** | `course_clickhouse` | `mod6`, `all` | `8123`, `9000` | `analytics_db` · `student` / `student_pass` · [Play UI](http://localhost:8123/play) |
| **Adminer** | `course_adminer` | `ui`, `all` | `8080` | [Веб-клиент](http://localhost:8080) (PostgreSQL + MySQL) |

## Команды стенда

**Запуск и сброс профилей:**

```bash
# Поднять нужный модуль (mod4 | mod5 | mod6 | ui | all)
docker compose --profile mod4 up -d
docker compose --profile all up -d

# Остановить контейнеры (данные в volumes сохраняются)
docker compose --profile all down

# Полный сброс стенда вместе с данными и volumes
docker compose --profile all down -v
```

**Загрузка учебных данных для практики:**

```bash
# PostgreSQL (подставьте нужный номер модуля: module_1 … module_6)
docker exec -i course_pg_primary psql -U student -d learning_db < practice/module_1/init.sql

# MySQL 8.4 (модуль 4)
docker exec -i course_mysql_innodb mysql -u student -pstudent_pass learning_db < practice/module_4/init_mysql.sql

# ClickHouse (модуль 6)
docker exec -i course_clickhouse clickhouse-client -u student --password student_pass -d analytics_db --multiquery < practice/module_6/init_clickhouse.sql
```

**Быстрый вход в CLI-клиенты:**

```bash
docker exec -it course_pg_primary psql -U student -d learning_db
docker exec -it course_mysql_innodb mysql -u student -pstudent_pass learning_db
docker exec -it course_clickhouse clickhouse-client -u student --password student_pass -d analytics_db
```

> [!TIP]
> Подробный разбор сервисов, портов и частых проблем при запуске — в [`docker_guide.html`](docker_guide.html).

## Справочник файлов

<details>
<summary>Полный список уроков (26)</summary>

- **Модуль 1 — Фундамент реляционных БД и базовый SQL**
  - [`lesson_1_1.html`](lessons/lesson_1_1.html) — Как устроены реляционные БД и запуск PostgreSQL
  - [`lesson_1_2.html`](lessons/lesson_1_2.html) — Создание таблиц, типы данных, ограничения и `INSERT`
  - [`lesson_1_3.html`](lessons/lesson_1_3.html) — Чтение, фильтрация и сортировка (`SELECT`, `WHERE`, `ORDER BY`, пагинация и `NULL`)
  - [`lesson_1_4.html`](lessons/lesson_1_4.html) — `UPDATE`, `DELETE` и первое объединение таблиц (`INNER JOIN`)
- **Модуль 2 — Проектирование схем и продвинутый SQL**
  - [`lesson_2_1.html`](lessons/lesson_2_1.html) — Нормализация (1НФ–3НФ), связи таблиц (1:1, 1:N, M:N) и основы миграций схемы БД
  - [`lesson_2_2.html`](lessons/lesson_2_2.html) — `LEFT JOIN`, `UNION`, `CASE WHEN`, `GROUP BY` и `HAVING`
  - [`lesson_2_3.html`](lessons/lesson_2_3.html) — Подзапросы, CTE, работа с датами, строками и `JSONB`
  - [`lesson_2_4.html`](lessons/lesson_2_4.html) — Оконные функции — аналитика без схлопывания строк
  - [`lesson_2_5.html`](lessons/lesson_2_5.html) — Практикум-чекпоинт: комплексные SQL-задачи на реальном датасете
- **Модуль 3 — Внутреннее устройство PostgreSQL**
  - [`lesson_3_1.html`](lessons/lesson_3_1.html) — Физическая архитектура PostgreSQL: страницы (8 КБ), Heap и Shared Buffers
  - [`lesson_3_2.html`](lessons/lesson_3_2.html) — Индексы: B-Tree, составные индексы, ловушки, GIN и BRIN
  - [`lesson_3_3.html`](lessons/lesson_3_3.html) — Чтение планов выполнения запросов: `EXPLAIN` и `EXPLAIN ANALYZE`
  - [`lesson_3_4.html`](lessons/lesson_3_4.html) — Журнал предзаписи (WAL) и восстановление после сбоев (Crash Recovery)
- **Модуль 4 — Транзакции, MVCC и сравнение с MySQL**
  - [`lesson_4_1.html`](lessons/lesson_4_1.html) — Транзакции, ACID и аномалии параллельного доступа
  - [`lesson_4_2.html`](lessons/lesson_4_2.html) — MVCC (многоверсионность) и `VACUUM` в PostgreSQL
  - [`lesson_4_3.html`](lessons/lesson_4_3.html) — Уровни изоляции и блокировки (Row-level locks и Deadlocks)
  - [`lesson_4_4.html`](lessons/lesson_4_4.html) — Архитектурная дуэль: PostgreSQL vs MySQL (движок InnoDB)
- **Модуль 5 — Репликация, бэкапы и эксплуатация**
  - [`lesson_5_1.html`](lessons/lesson_5_1.html) — Физическая потоковая репликация (Streaming Replication): Primary и Standby
  - [`lesson_5_2.html`](lessons/lesson_5_2.html) — Синхронная vs асинхронная репликация и диагностика Replication Lag
  - [`lesson_5_3.html`](lessons/lesson_5_3.html) — Логическая репликация и переключение при сбоях (Switchover / Failover)
  - [`lesson_5_4.html`](lessons/lesson_5_4.html) — Резервное копирование и PITR + пулинг соединений (PgBouncer)
- **Модуль 6 — DWH, OLAP и итоговый проект**
  - [`lesson_6_1.html`](lessons/lesson_6_1.html) — OLTP vs OLAP и размерное моделирование («Звезда» и «Снежинка»)
  - [`lesson_6_2.html`](lessons/lesson_6_2.html) — Партиционирование таблиц и материализованные представления в PostgreSQL
  - [`lesson_6_3.html`](lessons/lesson_6_3.html) — Колончатое хранение и OLAP-движки (ClickHouse): сжатие, векторизация и основы MPP/шардирования
  - [`lesson_6_4.html`](lessons/lesson_6_4.html) — Потоки данных ELT, идемпотентность и медленно меняющиеся измерения (SCD Type 2)
  - [`lesson_6_5.html`](lessons/lesson_6_5.html) — Итоговый проект: сквозной контур OLTP (PostgreSQL) → ELT → аналитическая витрина в OLAP

</details>

<details>
<summary>Структура репозитория</summary>

```text
db-mastery/
├── index.html             # Главная страница курса (оглавление, поиск, прогресс)
├── handout.html           # Сводный справочник (PostgreSQL, MySQL, ClickHouse, DWH)
├── docker_guide.html      # Гид по Docker-стенду и диагностике проблем
├── docker-compose.yaml    # Сервисы, профили и volumes стенда
├── assets/                # Стили, скрипты и локальные офлайн-библиотеки (fonts, highlightjs, mermaid)
├── lessons/               # 26 HTML-уроков (lesson_1_1.html … lesson_6_5.html)
├── practice/              # Практикумы по модулям (module_1 … module_6: practice.html + init*.sql)
├── slides/                # Презентации к каждому модулю (module-1.html … module-6.html)
└── templates/             # Шаблон урока для авторов (lesson.html)
```

</details>
