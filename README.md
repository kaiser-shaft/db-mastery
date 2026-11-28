# Изучение Баз Данных (`db-mastery`)

![PostgreSQL 16](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)
![MySQL 8.4](https://img.shields.io/badge/MySQL-8.4_InnoDB-4479A1?logo=mysql&logoColor=white)
![ClickHouse](https://img.shields.io/badge/ClickHouse-OLAP-FFCC01?logo=clickhouse&logoColor=black)
![Docker Compose](https://img.shields.io/badge/Docker_Compose-Stand-2496ED?logo=docker&logoColor=white)
![Курс](https://img.shields.io/badge/Курс-6_модулей_·_26_уроков-10B981)

Практический курс по базам данных: **6 модулей и 26 уроков** — от первого SQL-запроса и устройства страниц на диске до транзакций, MVCC, репликации, резервного копирования (PITR) и аналитических хранилищ (DWH / OLAP).

Весь учебный материал оформлен в виде полностью автономного офлайн веб-комплекса (открывается прямо в браузере без сборки, бэкенда и доступа в интернет — шрифты, Highlight.js и Mermaid хранятся локально) и дополнен готовым Docker-стендом.

[Быстрый старт](#-быстрый-старт) · [Как проходить практику](#-как-проходить-практику) · [Программа курса](#-программа-курса) · [Стенд и подключения](#-сервисы-и-параметры-подключения) · [Структура](#-структура-репозитория)

---

## Что внутри

- **26 HTML-уроков** ([`lessons/`](lessons/)) — структурированная теория, разбор внутреннего устройства СУБД и типовых ошибок.
- **6 презентаций** ([`slides/`](slides/)) — слайды к каждому модулю для быстрого обзора и повторения.
- **6 практических модулей** ([`practice/`](practice/)) — задания в формате [`practice.html`](practice/module_1/practice.html) и SQL-скрипты инициализации стенда (`init.sql`, `init_mysql.sql`, `init_clickhouse.sql`).
- **Главная страница** ([`index.html`](index.html)) — оглавление курса, поиск по урокам и отслеживание прогресса.
- **Справочник** ([`handout.html`](handout.html)) — шпаргалка по PostgreSQL, MySQL/InnoDB, ClickHouse и проектированию DWH.
- **Гид по стенду** ([`docker_guide.html`](docker_guide.html)) — подробная инструкция по Docker-окружению и диагностике проблем.

---

## Быстрый старт

### Требования

- **Docker** и **Docker Compose** (v2)
- Любой современный браузер
- Опционально: локальный SQL-клиент (DBeaver, DataGrip, `psql`) или встроенный в стенд веб-клиент **Adminer**

### Запуск

1. Клонируйте репозиторий и перейдите в директорию проекта:

   ```bash
   git clone https://github.com/kaiser-shaft/db-mastery.git
   cd db-mastery
   ```

2. Откройте [`index.html`](index.html) в браузере — это главная точка входа в курс.

3. Поднимите базовый контейнер PostgreSQL 16 (нужен для модулей 1–6):

   ```bash
   docker compose up -d
   ```

4. Убедитесь, что контейнер перешёл в состояние `healthy`, и проверьте подключение:

   ```bash
   docker compose ps
   docker exec -it course_pg_primary psql -U student -d learning_db
   ```

### Профили Docker Compose

Дополнительные сервисы включаются по мере прохождения модулей через профили из [`docker-compose.yaml`](docker-compose.yaml):

```bash
# Модуль 4: MySQL 8.4 (InnoDB) для сравнения с PostgreSQL
docker compose --profile mod4 up -d

# Модуль 5: физическая и логическая репликация + пулер PgBouncer
docker compose --profile mod5 up -d

# Модуль 6: колоночная OLAP-СУБД ClickHouse
docker compose --profile mod6 up -d

# Опционально: веб-клиент Adminer (http://localhost:8080)
docker compose --profile ui up -d

# Запустить все сервисы стенда одновременно
docker compose --profile all up -d
```

Управление состоянием стенда:

```bash
# Остановить контейнеры (данные в Docker volumes сохраняются)
docker compose --profile all down

# Полный сброс стенда с удалением всех volumes и данных
docker compose --profile all down -v
```

> Подробности по работе со стендом и решению типовых проблем — в [`docker_guide.html`](docker_guide.html).

---

## Как проходить практику

В каждом модуле (`practice/module_1` … `practice/module_6`) лежат файл с заданиями `practice.html` и скрипты подготовки данных:

- **PostgreSQL** (`practice/module_N/init.sql`):

  ```bash
  docker exec -i course_pg_primary psql -U student -d learning_db < practice/module_1/init.sql
  ```

- **MySQL 8.4** (модуль 4, `practice/module_4/init_mysql.sql`):

  ```bash
  docker exec -i course_mysql_innodb mysql -u student -pstudent_pass learning_db < practice/module_4/init_mysql.sql
  ```

- **ClickHouse** (модуль 6, `practice/module_6/init_clickhouse.sql`):

  ```bash
  docker exec -i course_clickhouse clickhouse-client -u student --password student_pass -d analytics_db --multiquery < practice/module_6/init_clickhouse.sql
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
<summary>Полный список уроков (26)</summary>

- **Модуль 1 — Фундамент реляционных БД и базовый SQL**
  - [`lesson_1_1.html`](lessons/lesson_1_1.html) — Как устроены реляционные БД и запуск PostgreSQL
  - [`lesson_1_2.html`](lessons/lesson_1_2.html) — Создание таблиц, типы данных, ограничения и `INSERT`
  - [`lesson_1_3.html`](lessons/lesson_1_3.html) — Чтение, фильтрация и сортировка (`SELECT`, `WHERE`, `ORDER BY`, пагинация и `NULL`)
  - [`lesson_1_4.html`](lessons/lesson_1_4.html) — `UPDATE`, `DELETE` и первое объединение таблиц (`INNER JOIN`)
- **Модуль 2 — Проектирование схем и продвинутый SQL**
  - [`lesson_2_1.html`](lessons/lesson_2_1.html) — Нормализация (1НФ–3НФ), связи «многие-ко-многим» и основы миграций схемы БД
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

---

## Сервисы и параметры подключения

| Сервис | Контейнер | Профиль | Порт | База и учётные данные |
| --- | --- | --- | --- | --- |
| **PostgreSQL 16 (Primary)** | `course_pg_primary` | по умолчанию | `5432` | `learning_db` · `student` / `student_pass` |
| **MySQL 8.4 (InnoDB)** | `course_mysql_innodb` | `mod4`, `all` | `3306` | `learning_db` · `student` / `student_pass` (`root` / `root_pass`) |
| **PostgreSQL 16 (Standby)** | `course_pg_standby` | `mod5`, `all` | `5433` | физическая потоковая реплика `pg_primary` |
| **PostgreSQL 16 (Logical)** | `course_pg_logical` | `mod5`, `all` | `5434` | `learning_db` · `student` / `student_pass` |
| **PgBouncer** | `course_pgbouncer` | `mod5`, `all` | `6432` | `learning_db` · `student` / `student_pass` (`pool_mode=transaction`) |
| **ClickHouse** | `course_clickhouse` | `mod6`, `all` | `8123`, `9000` | `analytics_db` · `student` / `student_pass` · [Play UI](http://localhost:8123/play) |
| **Adminer** | `course_adminer` | `ui`, `all` | `8080` | [Веб-интерфейс](http://localhost:8080) |

Строка подключения к основному PostgreSQL:

```text
postgresql://student:student_pass@localhost:5432/learning_db
```

> **Примечание для урока 5.4 (PITR):** в [`docker-compose.yaml`](docker-compose.yaml) у сервиса `pg_primary` закомментированы параметры `archive_mode` и `archive_command` (архивация WAL в `./backups/wal`). Чтобы выполнить практику по Point-in-Time Recovery, раскомментируйте эти строки и перезапустите контейнер командой `docker compose up -d pg_primary`.

---

## Структура репозитория

```text
db-mastery/
├── index.html             # Главная страница курса (оглавление, поиск, прогресс)
├── handout.html           # Сводный справочник (PostgreSQL, MySQL, ClickHouse, DWH)
├── docker_guide.html      # Подробный гид по Docker-стенду и отладке
├── docker-compose.yaml    # Конфигурация контейнеров, профилей и volumes
├── assets/                # Общие ресурсы и локальные офлайн-библиотеки
│   ├── css/               #   Стили уроков (lesson.css) и диаграмм (diagrams.css)
│   ├── js/                #   Скрипты уроков (lesson.js) и просмотрщика диаграмм (diagrams.js)
│   └── vendor/            #   Скачанные библиотеки (fonts, highlightjs, mermaid)
├── lessons/               # 26 HTML-уроков (lesson_1_1.html … lesson_6_5.html)
├── templates/             # Шаблон урока для авторов (lesson.html)
├── practice/              # Практикумы по модулям (module_1 … module_6)
│   ├── module_1..3,5/     #   practice.html + init.sql
│   ├── module_4/          #   practice.html + init.sql + init_mysql.sql
│   └── module_6/          #   practice.html + init.sql + init_clickhouse.sql
└── slides/                # Презентации к каждому модулю (module-1.html … module-6.html)
```
