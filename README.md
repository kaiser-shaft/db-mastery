# Изучение Баз Данных (`db-mastery`)

Практический курс по базам данных: **6 модулей и 26 уроков** — от первого SQL-запроса и устройства страниц на диске до транзакций, репликации, резервного копирования и аналитических хранилищ (DWH / OLAP).

Технологический стек стенда: **PostgreSQL 16**, **MySQL 8.4 (InnoDB)**, **ClickHouse**, **PgBouncer**, **Adminer**.

---

## Быстрый старт

1. Откройте в браузере главную страницу курса: [`index.html`](index.html) (содержит оглавление, поиск по урокам и отслеживание прогресса).
2. Поднимите базовый стенд PostgreSQL 16 с помощью Docker Compose:

```bash
docker compose up -d
```

3. Для работы с дополнительными модулями используйте профили из [`docker-compose.yaml`](docker-compose.yaml):

```bash
# Модуль 4 (MySQL 8.4 для сравнения с PostgreSQL)
docker compose --profile mod4 up -d

# Модуль 5 (репликация pg_standby, pg_logical и пулер PgBouncer)
docker compose --profile mod5 up -d

# Модуль 6 (ClickHouse для OLAP)
docker compose --profile mod6 up -d

# Веб-клиент Adminer (http://localhost:8080)
docker compose --profile ui up -d

# Запустить все сервисы стенда сразу
docker compose --profile all up -d
```

Подробная инструкция по запуску, подключению и решению типовых проблем находится в [`docker_guide.html`](docker_guide.html).

---

## Структура репозитория

```text
db-mastery/
├── index.html             # Главная страница курса (оглавление, поиск, прогресс)
├── cheatsheet.html        # Справочник по PostgreSQL, MySQL/InnoDB, ClickHouse и DWH
├── docker_guide.html      # Подробный гид по Docker-стенду курса
├── docker-compose.yaml    # Конфигурация контейнеров стенда
├── lessons/               # 26 HTML-уроков (lesson_1_1.html … lesson_6_5.html) + template.html
├── practice/              # Практические задания и SQL-инициализация по модулям (module_1 … module_6)
└── slides/                # Презентации к каждому модулю (module-1.html … module-6.html)
```

---

## Программа курса

| Модуль | Тема | Уроки | Слайды | Практика |
| --- | --- | --- | --- | --- |
| **Модуль 1** | Фундамент реляционных БД и базовый SQL | 1.1 – 1.4 | [`module-1.html`](slides/module-1.html) | [`practice.html`](practice/module_1/practice.html) |
| **Модуль 2** | Проектирование схем и продвинутый SQL | 2.1 – 2.5 | [`module-2.html`](slides/module-2.html) | [`practice.html`](practice/module_2/practice.html) |
| **Модуль 3** | Внутреннее устройство PostgreSQL: диск, память, индексы и WAL | 3.1 – 3.4 | [`module-3.html`](slides/module-3.html) | [`practice.html`](practice/module_3/practice.html) |
| **Модуль 4** | Транзакции, MVCC, блокировки и сравнение с MySQL/InnoDB | 4.1 – 4.4 | [`module-4.html`](slides/module-4.html) | [`practice.html`](practice/module_4/practice.html) |
| **Модуль 5** | Репликация, резервное копирование и эксплуатация (HA & Ops) | 5.1 – 5.4 | [`module-5.html`](slides/module-5.html) | [`practice.html`](practice/module_5/practice.html) |
| **Модуль 6** | Архитектура DWH, OLAP-движки и итоговый проект | 6.1 – 6.5 | [`module-6.html`](slides/module-6.html) | [`practice.html`](practice/module_6/practice.html) |

<details>
<summary>Полный список уроков</summary>

- **Модуль 1**
  - [`lesson_1_1.html`](lessons/lesson_1_1.html) — Как устроены реляционные БД и запуск PostgreSQL
  - [`lesson_1_2.html`](lessons/lesson_1_2.html) — Создание таблиц, типы данных, ограничения и `INSERT`
  - [`lesson_1_3.html`](lessons/lesson_1_3.html) — Чтение, фильтрация и сортировка (`SELECT`, `WHERE`, `ORDER BY`, пагинация и `NULL`)
  - [`lesson_1_4.html`](lessons/lesson_1_4.html) — `UPDATE`, `DELETE` и первое объединение таблиц (`INNER JOIN`)
- **Модуль 2**
  - [`lesson_2_1.html`](lessons/lesson_2_1.html) — Нормализация (1НФ–3НФ), связи «многие-ко-многим» и основы миграций схемы БД
  - [`lesson_2_2.html`](lessons/lesson_2_2.html) — `LEFT JOIN`, `UNION`, `CASE WHEN`, `GROUP BY` и `HAVING`
  - [`lesson_2_3.html`](lessons/lesson_2_3.html) — Подзапросы, CTE, работа с датами, строками и `JSONB`
  - [`lesson_2_4.html`](lessons/lesson_2_4.html) — Оконные функции — аналитика без схлопывания строк
  - [`lesson_2_5.html`](lessons/lesson_2_5.html) — Практикум-чекпоинт: комплексные SQL-задачи на реальном датасете
- **Модуль 3**
  - [`lesson_3_1.html`](lessons/lesson_3_1.html) — Физическая архитектура PostgreSQL: страницы (8 КБ), Heap и Shared Buffers
  - [`lesson_3_2.html`](lessons/lesson_3_2.html) — Индексы: B-Tree, составные индексы, ловушки, GIN и BRIN
  - [`lesson_3_3.html`](lessons/lesson_3_3.html) — Чтение планов выполнения запросов: `EXPLAIN` и `EXPLAIN ANALYZE`
  - [`lesson_3_4.html`](lessons/lesson_3_4.html) — Журнал предзаписи (WAL) и восстановление после сбоев (Crash Recovery)
- **Модуль 4**
  - [`lesson_4_1.html`](lessons/lesson_4_1.html) — Транзакции, ACID и аномалии параллельного доступа
  - [`lesson_4_2.html`](lessons/lesson_4_2.html) — MVCC (многоверсионность) и `VACUUM` в PostgreSQL
  - [`lesson_4_3.html`](lessons/lesson_4_3.html) — Уровни изоляции и блокировки (Row-level locks и Deadlocks)
  - [`lesson_4_4.html`](lessons/lesson_4_4.html) — Архитектурная дуэль: PostgreSQL vs MySQL (движок InnoDB)
- **Модуль 5**
  - [`lesson_5_1.html`](lessons/lesson_5_1.html) — Физическая потоковая репликация (Streaming Replication): Primary и Standby
  - [`lesson_5_2.html`](lessons/lesson_5_2.html) — Синхронная vs асинхронная репликация и диагностика Replication Lag
  - [`lesson_5_3.html`](lessons/lesson_5_3.html) — Логическая репликация и переключение при сбоях (Switchover / Failover)
  - [`lesson_5_4.html`](lessons/lesson_5_4.html) — Резервное копирование и PITR + пулинг соединений (PgBouncer)
- **Модуль 6**
  - [`lesson_6_1.html`](lessons/lesson_6_1.html) — OLTP vs OLAP и размерное моделирование («Звезда» и «Снежинка»)
  - [`lesson_6_2.html`](lessons/lesson_6_2.html) — Партиционирование таблиц и материализованные представления в PostgreSQL
  - [`lesson_6_3.html`](lessons/lesson_6_3.html) — Колончатое хранение и OLAP-движки (ClickHouse): сжатие, векторизация и основы MPP/шардирования
  - [`lesson_6_4.html`](lessons/lesson_6_4.html) — Потоки данных ELT, идемпотентность и медленно меняющиеся измерения (SCD Type 2)
  - [`lesson_6_5.html`](lessons/lesson_6_5.html) — Итоговый проект: сквозной контур OLTP (PostgreSQL) → ELT → аналитическая витрина в OLAP

</details>

---

## Сервисы и параметры подключения

| Сервис | Контейнер | Профиль | Порт | База / Доступ |
| --- | --- | --- | --- | --- |
| PostgreSQL 16 (Primary) | `course_pg_primary` | по умолчанию | `5432` | `learning_db` · `student` / `student_pass` |
| MySQL 8.4 (InnoDB) | `course_mysql_innodb` | `mod4`, `all` | `3306` | `learning_db` · `student` / `student_pass` (root: `root_pass`) |
| PostgreSQL 16 (Standby) | `course_pg_standby` | `mod5`, `all` | `5433` | физическая реплика `pg_primary` |
| PostgreSQL 16 (Logical) | `course_pg_logical` | `mod5`, `all` | `5434` | `learning_db` · `student` / `student_pass` |
| PgBouncer | `course_pgbouncer` | `mod5`, `all` | `6432` | `learning_db` · `student` / `student_pass` |
| ClickHouse | `course_clickhouse` | `mod6`, `all` | `8123`, `9000` | `analytics_db` · `student` / `student_pass` · [Play UI](http://localhost:8123/play) |
| Adminer | `course_adminer` | `ui`, `all` | `8080` | [Веб-интерфейс](http://localhost:8080) |

> Для урока 5.4 (PITR) в [`docker-compose.yaml`](docker-compose.yaml) нужно раскомментировать параметры `archive_mode` и `archive_command` у сервиса `pg_primary` и перезапустить контейнер.
