# marriage_early_stopping — контекст проекта

## Что это
Идиоматичный порт шуточного Python-класса `MarriageEarlyStopping`
(early stopping из ML, применённое к отношениям) — шесть независимых
реализаций одного и того же сценария на двух языках. Сравнение парадигм
и уровня строгости на одной задаче, а не «правильный» и «неправильный»
варианты.

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

## Структура репозитория
```
vs_python/
├── CLAUDE.md, README.md, LICENSE, .gitignore, .vscode/, Makefile   — общее для репозитория
├── ocaml/    — lib/ (три варианта логики) + bin/ (тонкие исполняемые файлы)
│             + test/ (Alcotest) + dune-project/.opam + своя песочница _opam/
└── python/   — три .py-варианта + tests/ (pytest) + pyproject.toml/uv.lock
              + своё окружение .venv/ (управляется uv)
```
Каждый язык — независимый под-проект со своей изолированной песочницей
(`ocaml/_opam/`, `python/.venv/`), не пересекается с другими OCaml/Python-
проектами в остальной рабочей области. Детали сборки, архитектуры,
тестов и принятых решений — в CLAUDE.md соответствующей папки.

## Makefile — единая точка входа для демо и тестов
Корневой `Makefile` оборачивает обе песочницы, чтобы не держать в
голове разные команды (`opam exec -- dune ...` vs `uv run ...`).
`make help` печатает список целей с описаниями. Основные:
- `make setup` — поднять обе песочницы с нуля (opam switch + uv sync).
- `make demo` — прогнать все шесть вариантов подряд.
- `make test` — Alcotest (OCaml) + pytest (Python).
- `make lint` / `make fmt` — ruff (только Python; для OCaml
  форматирование — через `ocamlformat-rpc` в редакторе, отдельной
  make-цели нет).

## Лицензия
[The Unlicense](LICENSE) — общественное достояние, без каких-либо
условий на использование. Относится ко всему репозиторию, обеим папкам.

## Открытые вопросы
Нет — на момент хэндоффа проект в стабильном рабочем состоянии,
дальнейших задач не запрошено.
