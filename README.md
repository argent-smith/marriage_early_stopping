# marriage_early_stopping

Шуточный Python-класс `MarriageEarlyStopping` — техника early stopping
из машинного обучения, применённая к отношениям — портирован девять
раз на три языка. Учебный пример: как один и тот же сценарий выглядит
в разных парадигмах и при разном уровне строгости, от буквальной
транскрипции с багами оригинала до идиоматичного FP с монадами.

## Структура

```
ocaml/    — три OCaml-порта, свой dune-project и локальная песочница
python/   — три Python-варианта, свой pyproject.toml и .venv
ruby/     — три Ruby-варианта, свой Gemfile и vendor/bundle
```

Подробности архитектуры и разбор конкретных решений в каждой папке —
в [CLAUDE.md](CLAUDE.md), [ocaml/CLAUDE.md](ocaml/CLAUDE.md),
[python/CLAUDE.md](python/CLAUDE.md) и [ruby/CLAUDE.md](ruby/CLAUDE.md).

## Быстрый старт

```sh
make setup   # opam switch в ocaml/ + окружение python/.venv через uv + гемы в ruby/vendor/bundle
make demo    # прогнать все девять вариантов подряд
make test    # Alcotest (OCaml) + pytest (Python) + RSpec (Ruby)
```

`make help` — полный список целей.

## Что показывает пример

### OCaml (`ocaml/`)

- `marriage_early_stopping.ml` — функциональный порт: чистое ядро
  (`Tracker`) отдельно от вывода, события как данные (`Event`), а не
  текст, вывод через подключаемый `Logger` (ISP), два независимых
  представления одних и тех же событий (текстовое и sexp) без единой
  правки ядра (OCP). Ошибки — через `Or_error`, а не исключения;
  инфиксная монадическая композиция (`let open Or_error in ...`,
  `let open Option in ...`). Ни одного `if-then-else` — булевы
  проверки заменены комбинаторами (`Result.ok_if_true`,
  `Ordering.of_int`).
- `marriage_early_stopping_oop.ml` — объектный порт: `Tracker` —
  настоящий OCaml `class` с mutable-полями и методом
  `check_atmosphere`, ближе по духу к мутируемому `self` оригинала, но
  с теми же принципами (без if, без тихих ошибок на невалидный
  `patience`).
- `marriage_early_stopping_naive.ml` — тот же `class`, но без единого
  сознательного архитектурного решения: `if`/`else`, `print` прямо в
  методах, никакой валидации `patience` — баг оригинала (сброс на
  каждом оверфит-дне при `patience <= 0`) воспроизводится буквально.

### Python (`python/`)

- `marriage_early_stopping.py` — оригинал (транскрипция скриншота,
  1:1): один класс, три метода, мутация `self`, без разделения на
  модули и без обработки ошибок. Ниже в том же файле — отдельно
  помеченная обвязка для запуска (её не было в скриншоте), включая
  честный комментарий про баг оригинала, который эта обвязка не чинит.
- `marriage_early_stopping_oop.py` — рефакторинг в духе SOLID и Sandy
  Metz: `Event` — иерархия классов с полиморфным `render()` вместо
  ветвления по типу, `Tracker` — маленькие однострочные-пятистрочные
  методы, DI логгера через конструктор, ошибка `patience` — через
  исключение.
- `marriage_early_stopping_fp.py` — продвинутый FP-стиль на монадах
  `returns` (dry-python): иммутабельный `@dataclass(frozen=True)`
  `Tracker`, `Result`/`Maybe` вместо исключений и `None`, `.map`/`.bind`,
  `functools.reduce` вместо цикла с накоплением.

### Ruby (`ruby/`)

- `marriage_early_stopping_naive.rb` — буквальный порт: `if`/`else`,
  `puts` прямо в методах, никакой валидации `patience`, эмодзи (🚨,
  🔄) — та же точка сравнения, что и `_naive.ml`/Python-оригинал.
- `marriage_early_stopping_oop.rb` — SOLID + Sandy Metz: события —
  `Data.define` с полиморфным `#render` вместо ветвления по типу,
  `Tracker` — маленькие однострочные-пятистрочные методы ("tell,
  don't ask"), ошибка `patience` — через исключение.
- `marriage_early_stopping_fp.rb` — продвинутый FP-стиль на `dry-rb`
  (`dry-monads`+`dry-struct`+`dry-validation`+`dry-initializer`, та же
  организация, что `returns` — для Python): `Tracker` и события —
  неизменяемый `Dry::Struct`, обновления через `tracker.new(...)`
  (аналог `dataclasses.replace`/`{ t with ... }`), `Result`/`Maybe`
  вместо исключений и `nil`, поведение — маленькие классы с DI
  (`extend Dry::Initializer`), а не модуль функций.

## Сборка, запуск, тесты

Ниже — то, что делают `make setup`/`make demo`/`make test` под
капотом, на случай если нужно запустить что-то одно вручную.

### OCaml

```sh
cd ocaml
opam switch create . 5.3.0 --yes
opam install . --deps-only --with-test --yes   # core, ppx_jane, alcotest — по depends из .opam
dune build
dune exec ./bin/marriage_early_stopping.exe         # функциональный вариант
dune exec ./bin/marriage_early_stopping_oop.exe     # объектный вариант
dune exec ./bin/marriage_early_stopping_naive.exe   # объектный, буквальный порт
dune test                                            # Alcotest, 11 юнит-тестов
```

Проект использует локальный opam switch (песочница `ocaml/_opam/`,
изолирована от прочих OCaml-проектов) и оформлен как opam-пакет —
[ocaml/marriage_early_stopping.opam](ocaml/marriage_early_stopping.opam)
генерируется dune из `dune-project` (сам файл не редактируется, в нём
только служебная пометка об этом). Логика каждого варианта — в `lib/`
(библиотека, чтобы её мог `open` тест), исполняемые файлы в `bin/` —
тонкие обёртки.

### Python

```sh
cd python
uv sync                                           # .venv + returns/pytest/ruff по uv.lock
uv run python marriage_early_stopping.py          # оригинал + обвязка
uv run python marriage_early_stopping_oop.py      # SOLID + Sandy Metz
uv run python marriage_early_stopping_fp.py       # монады (returns)
uv run pytest                                     # 17 тестов
uv run ruff check . && uv run ruff format --check .
```

Изолированное окружение — `python/.venv/`, управляется `uv`
(`python/uv.lock` фиксирует точные версии всего дерева зависимостей —
`returns` для рантайма, `pytest`/`ruff` только для разработки, из
`[dependency-groups] dev`). `ruff` форматирует всё, кроме
`marriage_early_stopping.py` — это 1:1 транскрипция скриншота, стиль
кода в ней намеренно не трогается.

### Ruby

```sh
cd ruby
bundle install                                       # vendor/bundle по Gemfile.lock
bundle exec ruby marriage_early_stopping_naive.rb     # буквальный порт
bundle exec ruby marriage_early_stopping_oop.rb       # SOLID + Sandy Metz
bundle exec ruby marriage_early_stopping_fp.rb        # монады (dry-monads)
bundle exec rspec                                     # 20 тестов
bundle exec rubocop
```

Требуется Ruby 4.0.6 (`.ruby-version`, подхватывается `rbenv`
автоматически при `cd` в папку). Изолированное окружение —
`ruby/vendor/bundle/`, путь зафиксирован в закоммиченном
`.bundle/config`, так что `bundle install` сразу ставит гемы в
песочницу, а не в системный/rbenv-global gem path.

## Лицензия

[The Unlicense](LICENSE) — общественное достояние, без каких-либо
условий на использование. Относится ко всему репозиторию.
