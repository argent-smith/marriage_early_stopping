# marriage_early_stopping — контекст проекта

## Что это
Идиоматичный OCaml-порт шуточного Python-класса `MarriageEarlyStopping`
(early stopping из ML, применённое к отношениям). Разложен по SOLID,
интегрирован с Jane Street Core, монадическая композиция — в инфиксной
нотации.

## Файлы (все в корне)
- `dune-project` — метаданные проекта и opam-пакета (`name`, `license`,
  `authors`, `source`, секция `package` с `synopsis`/`description`/
  `depends`) плюс `(generate_opam_files true)`. `dune`, помимо
  `(executable ...)`, добавляет `(public_name marriage_early_stopping)`
  — без него исполняемый файл не привязан к пакету и не ставится
  через `opam install .`. Препроцессинг `(pps ppx_jane)` — нужен для
  `[@@deriving sexp_of]`, `[%string ...]` (ppx_string) и
  `let%bind.Or_error` (там, где инфикс не использован).
- `marriage_early_stopping.opam` — генерируется dune из
  `dune-project`, вручную не редактируется (первая строка файла об
  этом явно предупреждает). Пересоздаётся любым `dune build`, если
  `dune-project` менялся. Проверено `opam lint` — проходит без замечаний.
- `marriage_early_stopping.ml` — единственный OCaml-исходник.
- `marriage_early_stopping.py` — оригинал, с которого делался порт
  (транскрипция из скриншота, 1:1, для сравнения). Класс с мутируемым
  `self`, тремя методами (`__init__`, `check_atmosphere`,
  `trigger_reset`), без разделения на модули и без обработки ошибок —
  именно это переписано на иммутабельные типы + SOLID в .ml-файле.

## Архитектура (SOLID)
- `Tracker` — чистое ядро, иммутабельный `'a t` (patience,
  overfit_counter, best_loss, checkpoint). Ничего не знает о выводе.
- `Event` — что произошло на шаге, как данные (`[@@deriving sexp_of]`),
  а не текст.
- `Logger` (module type, ISP) — один метод `log : string -> unit`.
- `Presenter(L : Logger)` — рендерит `Event.t` в текст, как в
  Python-оригинале.
- `Sexp_presenter(L : Logger)` — второй способ вывода (structured/sexp)
  без единой правки Tracker/Event — рабочая демонстрация OCP, реально
  вызывается в `run` на событиях последнего дня.

## Монадическая композиция — инфиксная нотация
- `Tracker.create` возвращает `'a t Or_error.t` (валидация
  `patience > 0`). В `run`:
  `Or_error.(Tracker.create ... >>| fun tracker -> ...)`.
- `Tracker.reset` и `check_atmosphere`:
  `Option.(opt >>| f) |> Option.value ~default:...`
  вместо ручного `match` или `Option.value_map`.
- Инфикс применён только там, где есть реальная цепочка шагов; простую
  композицию функций в монаду не заворачивали — см. комментарии в
  файле про "где необходимо".

## Вывод текста
`[%string "...%{expr}..."]` (ppx_string, часть ppx_jane) вместо
`Printf.sprintf` с позиционными аргументами. Для числового формата
`%.3f` (ppx_string это не покрывает) — сначала `sprintf "%.3f" loss`,
затем интерполируем уже готовую строку.

## Сборка и запуск
Проект использует локальный opam switch (песочница `_opam/` в корне
проекта) — зависимости изолированы от глобального switch и от других
OCaml-проектов в рабочей области. Сами зависимости (`core`,
`ppx_jane`) объявлены не вручную, а в `depends` пакета
`marriage_early_stopping.opam` (генерируется из `dune-project`).

Первоначальная настройка (один раз):
```
opam switch create . 5.3.0 --yes
opam install . --deps-only --yes   # core, ppx_jane — из depends .opam
opam install ocaml-lsp-server ocamlformat --yes   # для редактора, см. ниже
```

Сборка и запуск:
```
dune build
dune exec ./marriage_early_stopping.exe
```

Локальный switch подхватывается автоматически при `cd` в директорию
проекта (opam ставит cd-хук в шелл при `opam init`; для fish —
`env_hook.fish`, уже подключён). Если авто-активация не сработала
(вложенный шелл, CI без хука) — явно: `opam exec -- dune build`.

`_opam/` и `_build/` — генерируемые директории, в репозиторий не
входят.

### Редактор (VS Code + OCaml Platform)
Расширению нужны собственные `ocamllsp` и `ocamlformat-rpc` — а не те,
что стоят в глобальном switch рабочей области. Обе версии (LSP-сервер
и dune, генерирующий merlin-конфиг) должны совпадать, иначе
"incompatible version of Dune"; без `ocamlformat` (>0.21.0, даёт
бинарь `ocamlformat-rpc`) типы при наведении не форматируются.
`.vscode/settings.json` явно фиксирует sandbox:
```json
"ocaml.sandbox": { "kind": "opam", "switch": "/Users/paul/work/ocaml/vs_python" }
```
После установки пакетов или пересоздания switch — команда в VS Code
**OCaml: Restart Language Server** (расширение не подхватывает новое
окружение само, пока не перезапустишь ocamllsp-процесс).

## Уже проверено
- 2026-08-10, macOS, локальный opam switch (`_opam/`, OCaml 5.3.0,
  `core` v0.17.1, `ppx_jane` v0.17.0): `dune build` и `dune exec`
  через `opam exec --` дают тот же вывод, что и ниже — сборка в
  изолированной песочнице подтверждена рабочей.
- 2026-08-10: `marriage_early_stopping.opam` сгенерирован из
  `dune-project` (`opam-version: "2.0"`), `opam lint` — без замечаний.
  `dune build @install` и `dune exec marriage_early_stopping` (по
  `public_name`, не только по имени .exe) проходят без ошибок.
- Исторически (первая итерация): компилировалось и запускалось под
  OCaml 5.2.0 на Ubuntu 24.04 (apt даёт только 4.14 — под core/ppx_jane
  пришлось поднимать 5.2.0 через opam). Тот конкретный switch не
  переносился — текущая песочница создана заново на 5.3.0, см. выше.
- Штатный прогон (5 дней, patience=3): чекпоинты на day1/day2,
  overfit-счётчик 1/3→3/3, срабатывает `Reset_triggered`.
- Ошибочный путь (`patience=0`): читаемое сообщение через `Or_error`
  — специально НЕ через `Or_error.error_s`/`[%message]`, потому что
  sexp-квотирование Sexplib экранирует кириллицу в восьмеричные
  escape-последовательности; для человека читаемого текста
  используется `Or_error.error_string`.
- Ветка `Reset_skipped` (сброс без чекпоинта) физически недостижима в
  текущей `daily_logs` — `best_loss` стартует с `infinity`, поэтому
  первый же день всегда становится новым лучшим. Сам комбинатор
  (`Option.(_ >>| f) |> Option.value ~default`) отдельно проверен
  изолированным тестом на None/Some.

## Открытые вопросы
Нет — на момент хэндоффа проект в стабильном рабочем состоянии,
дальнейших задач не запрошено.
