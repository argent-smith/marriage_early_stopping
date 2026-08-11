# marriage_early_stopping — контекст проекта

## Что это
Идиоматичный порт шуточного Python-класса `MarriageEarlyStopping`
(early stopping из ML, применённое к отношениям) — двенадцать
независимых реализаций одного и того же сценария на четырёх языках.
Сравнение парадигм и уровня строгости на одной задаче, а не
«правильный» и «неправильный» варианты.

- **OCaml** (`ocaml/`, подробности — [ocaml/CLAUDE.md](ocaml/CLAUDE.md)):
  - `marriage_early_stopping` — функциональный: SOLID через модули,
    иммутабельный `Tracker`, монадическая композиция, без if-then-else.
  - `marriage_early_stopping_oop` — объектный: настоящий OCaml `class`
    с mutable-состоянием, но всё ещё без if и без тихих ошибок.
  - `marriage_early_stopping_naive` — буквальный `class`-порт без
    единого архитектурного решения — воспроизводит даже баги оригинала.
- **Python** (`python/`, подробности — [python/CLAUDE.md](python/CLAUDE.md)):
  - `marriage_early_stopping.py` — оригинал (транскрипция скриншота,
    1:1) плюс отдельно помеченная обвязка для запуска.
  - `marriage_early_stopping_oop.py` — рефакторинг в духе SOLID и Sandy
    Metz (маленькие методы, полиморфизм вместо ветвления по типу события).
  - `marriage_early_stopping_fp.py` — продвинутый FP-стиль на монадах
    `returns` (dry-python): `Result`/`Maybe`, `.bind`/`.map`, `reduce`.
- **Ruby** (`ruby/`, подробности — [ruby/CLAUDE.md](ruby/CLAUDE.md)):
  - `marriage_early_stopping_naive.rb` — буквальный порт: `if`/`else`,
    `puts` прямо в методах, никакой валидации `patience`, эмодзи.
  - `marriage_early_stopping_oop.rb` — SOLID + Sandy Metz: `Data.define`
    события с полиморфным `#render`, маленькие методы, "tell don't ask".
  - `marriage_early_stopping_fp.rb` — продвинутый FP-стиль на
    `dry-rb` (`dry-monads`+`dry-struct`+`dry-validation`+`dry-initializer`,
    та же организация, что `returns` для Python): `Result`/`Maybe`,
    `.fmap`, данные — `Dry::Struct`, иммутабельные обновления через
    `tracker.new(...)`, композиция маленьких DI-классов, а не модуля
    функций.
- **Scala** (`scala/`, подробности — [scala/CLAUDE.md](scala/CLAUDE.md)):
  - `MarriageEarlyStoppingNaive.scala` — буквальный порт: `if`/`else`,
    `println` прямо в методах, никакой валидации `patience`, эмодзи,
    `null` вместо `Option` — та же точка сравнения, что и в остальных
    naive-вариантах.
  - `MarriageEarlyStoppingOop.scala` — SOLID + полиморфизм: `sealed
    trait Event` с переопределённым `render` в каждом `case
    class`/`case object`, mutable `Tracker`, "tell don't ask".
  - `MarriageEarlyStoppingFp.scala` — продвинутый FP-стиль на `cats`
    (та же организация, что `returns`/`dry-rb`): `Either`/`Option`
    stdlib-комбинаторы, `cats.data.Validated` для валидации, `case
    class` с `.copy(...)` для иммутабельных обновлений, композиция
    маленьких DI-классов. Scala 3.8.4 (топовая на момент работы,
    сверено по Maven Central), тулинг — `scala-cli`.

## Структура репозитория
```
vs_python/
├── CLAUDE.md, README.md, LICENSE, .gitignore, .vscode/, Makefile   — общее для репозитория
├── ocaml/    — lib/ (три варианта логики) + bin/ (тонкие исполняемые файлы)
│             + test/ (Alcotest) + dune-project/.opam + своя песочница _opam/
├── python/   — три .py-варианта + tests/ (pytest) + pyproject.toml/uv.lock
│             + своё окружение .venv/ (управляется uv)
├── ruby/     — три .rb-варианта + spec/ (RSpec) + Gemfile/Gemfile.lock
│             + своё окружение vendor/bundle/ (управляется bundler)
└── scala/    — три .scala-варианта + test/ (munit) + project.scala
              + coursier-кеш общесистемный (scala-cli, без vendoring)
```
Каждый язык — независимый под-проект со своей изолированной песочницей
(`ocaml/_opam/`, `python/.venv/`, `ruby/vendor/bundle/`) — кроме Scala,
где `scala-cli` сам управляет версией языка и зависимостями через
`project.scala` и общесистемный coursier-кеш (устройство JVM-экосистемы
не предполагает vendoring зависимостей в директорию проекта, как
opam/uv/bundler; воспроизводимость даёт не отдельная песочница, а
явная версия каждого пакета в `//> using`-директивах). Не пересекается
с другими OCaml/Python/Ruby/Scala-проектами в остальной рабочей
области. Детали сборки, архитектуры, тестов и принятых решений — в
CLAUDE.md соответствующей папки.

## Makefile — единая точка входа для демо и тестов
Корневой `Makefile` оборачивает все четыре песочницы, чтобы не держать
в голове разные команды (`opam exec -- dune ...` vs `uv run ...` vs
`bundle exec ...` vs `scala-cli ...`). `make help` печатает список
целей с описаниями. Основные:
- `make setup` — поднять все четыре песочницы с нуля (opam switch + uv
  sync + bundle install + прогрев coursier-кеша scala-cli).
- `make demo` — прогнать все двенадцать вариантов подряд.
- `make test` — Alcotest (OCaml) + pytest (Python) + RSpec (Ruby) +
  munit (Scala).
- `make lint` / `make fmt` — ruff (Python) + rubocop (Ruby) +
  scalafmt/scalafix (Scala); для OCaml форматирование — через
  `ocamlformat-rpc` в редакторе, отдельной make-цели нет.

## Лицензия
[The Unlicense](LICENSE) — общественное достояние, без каких-либо
условий на использование. Относится ко всему репозиторию, всем четырём
папкам.

## Открытые вопросы
Нет — на момент хэндоффа проект в стабильном рабочем состоянии,
дальнейших задач не запрошено.
