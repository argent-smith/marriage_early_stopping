# marriage_early_stopping/ocaml — контекст под-проекта

Три независимых OCaml-порта одного Python-оригинала (см. корневой
[../CLAUDE.md](../CLAUDE.md) и [../python/CLAUDE.md](../python/CLAUDE.md)
для трёх Python-вариантов и общей картины). Из корня репозитория есть
`make demo-ocaml`/`make test-ocaml`/`make setup-ocaml` — обёртки над
командами ниже, см. [../CLAUDE.md](../CLAUDE.md).

## Файлы (все в этой папке)
Логика каждого варианта живёт в `lib/`, исполняемые файлы в `bin/` —
тонкие обёртки, юнит-тесты в `test/` (см. «Тесты» ниже). Раньше вся
логика и точка входа были в одном файле на исполняемый файл; так было
проще, но не давало Alcotest ничего импортировать (у executable нет
внешнего интерфейса, только у library). Разнесли, сохранив внешнее
поведение бинарников побайтово тем же (сверено `dune build`/`dune
exec` до и после).

- `dune-project` — метаданные проекта и opam-пакета (`name`, `license`,
  `authors`, `source`, секция `package` с `synopsis`/`description`/
  `depends`, включая `alcotest {with-test}`) плюс
  `(generate_opam_files true)`.
- `marriage_early_stopping.opam` — генерируется dune из
  `dune-project`, вручную не редактируется (первая строка файла об
  этом явно предупреждает). Пересоздаётся любым `dune build`, если
  `dune-project` менялся. Проверено `opam lint` — проходит без замечаний.
- `lib/dune` — одна `(library (name marriage_early_stopping_lib)
  (wrapped false) ...)` на все три модуля сразу (общие
  `libraries`/`preprocess`); `(wrapped false)` — модули доступны как
  `Marriage_early_stopping_core`/`_oop_core`/`_naive_core` напрямую, без
  дополнительного префикса библиотеки. Препроцессинг `(pps ppx_jane)`
  — нужен для `[@@deriving sexp_of, equal]`, `[%string ...]`
  (ppx_string) и `let%bind.Or_error` (там, где инфикс не использован).
- `lib/marriage_early_stopping_core.ml` — функциональный порт
  (SOLID/модули), см. «Архитектура (SOLID)» ниже.
- `lib/marriage_early_stopping_oop_core.ml` — объектный порт (`class`),
  см. «Архитектура (OOP)» ниже. Свой `Event`/`Logger`/`Presenter`/
  `Sexp_presenter` — дублирует определения из функционального файла
  вместо общей библиотеки, чтобы модуль оставался самодостаточным для
  чтения отдельно, как и `.py`-оригинал. Плюс два read-only метода
  (`overfit_counter`, `best_loss`) — добавлены специально для
  Alcotest-тестов, чтобы проверять внутреннее состояние объекта, не
  трогая инкапсуляцию мутацией снаружи.
- `lib/marriage_early_stopping_naive_core.ml` — наивный `class`-порт,
  см. «Архитектура (naive)» ниже. Без модуля-обёртки (`class` сразу на
  верхнем уровне, как плоский Python-класс), без `Event`/`Logger` —
  `print_endline`/`printf` прямо в методах. Тоже с двумя read-only
  методами-аксессорами для тестов (`overfit_counter`,
  `best_relationship_loss`).
- `bin/dune` — `(executables (names marriage_early_stopping
  marriage_early_stopping_oop marriage_early_stopping_naive)
  (public_names ...) (libraries core marriage_early_stopping_lib) ...)`;
  без `public_names` бинарники не привязаны к пакету и не ставятся
  через `opam install .`.
- `bin/marriage_early_stopping.ml`, `bin/marriage_early_stopping_oop.ml`
  — по три строки: вызвать `<Module>_core.run ()`, сматчить
  `Ok`/`Error`. `bin/marriage_early_stopping_naive.ml` — одна строка
  (`Marriage_early_stopping_naive_core.run ()`), у naive-варианта нет
  `Or_error`, поэтому и матчить нечего.

## Архитектура (SOLID, lib/marriage_early_stopping_core.ml)
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

## Архитектура (OOP, lib/marriage_early_stopping_oop_core.ml)
Настоящая объектная система OCaml (`class`/`object`), а не только
модули — второй, независимый ответ на тот же Python-класс:
- `Tracker.t` — `class ['a] t ~patience ()`, три `val mutable`-поля
  (`overfit_counter`, `best_loss`, `checkpoint`) вместо иммутабельного
  record; один метод `check_atmosphere`, мутирующий состояние через
  `<-` и возвращающий `'a * Event.t list` — состояние объекта меняется
  в месте, а не пересобирается заново, как в функциональном варианте.
  Ближе по духу к мутируемому `self` Python-оригинала, но без if и без
  тихих ошибок (см. ниже).
- `Tracker.create` — не метод класса, а обычная функция-фабрика:
  `Result.ok_if_true (patience > 0) ~error:... >>| fun () -> new t
  ~patience ()`. Валидация происходит до `new`, поэтому сам класс
  безусловно доверяет `patience > 0` и не дублирует проверку в
  конструкторе.
- Внутри `check_atmosphere` — те же приёмы, что и в функциональном
  файле: `Ordering.of_int (Float.compare / Int.compare)` вместо if,
  `Option.(checkpoint >>| f) |> Option.value ~default` для сборки
  `Reset_triggered`/`Reset_skipped`, `Option.iter checkpoint ~f:(fun _
  -> overfit_counter <- 0)` — сбрасывает счётчик, только если чекпоинт
  реально был (тот же случай, что в функциональном `Tracker.reset`,
  просто выражен мутацией, а не пересборкой record).
- `Event`/`Logger`/`Presenter`/`Sexp_presenter` — структурно идентичны
  функциональному файлу (это не про SOLID-vs-OOP, а про представление
  результата), просто продублированы для самодостаточности файла.
- `run`: `List.fold` по `daily_logs` нужен только для протаскивания
  `current_state` (аналог `current_state.copy()` из Python) — сам
  `tracker` не возвращается из шага в шаг, он один и мутирует себя
  сам, вызывается как `tracker#check_atmosphere ~daily_loss ~current_state`.

## Архитектура (naive, lib/marriage_early_stopping_naive_core.ml)
Буквальный `class`-порт Python-оригинала — что получилось бы без всех
приёмов из «Без if-then-else» и без SOLID-разделения. Третья точка
сравнения, не «лучше» и не «хуже» двух других, а иллюстрация того, во
что превращаются те же 27 строк Python без единого сознательного
архитектурного решения:
- `class marriage_early_stopping ?(patience = 3) ()` — сразу на
  верхнем уровне файла, без обёртки в module `Tracker`; имена полей и
  методов взяты 1:1 из Python (`best_relationship_loss`,
  `checkpoint_memories`, `trigger_reset`), а не сокращены, как в
  `marriage_early_stopping_oop_core.ml` (`best_loss`, `checkpoint`).
- `check_atmosphere` — обычный `if daily_loss < best_relationship_loss
  then ... else ...`, `print_endline`/`printf` прямо внутри метода
  (никакого `Event`/`Logger`/`Presenter`).
- `patience` не валидируется вообще — конструктор просто принимает
  число. При `patience <= 0` (проверено: временная правка `~patience:0`
  + откат) логика ломается ровно так, как в Python: `overfit_counter
  >= patience` истинно уже после первого оверфит-дня, `trigger_reset`
  срабатывает на каждом шаге подряд, вместо накопления терпения.
  Это ровно тот баг, от которого `Tracker.create`/`Or_error` защищают
  в двух других файлах.
- `current_state : string ref`, мутируется через `:=` внутри
  `trigger_reset` — калька `current_state.load(...)`, мутирующего
  объект по ссылке в Python, а не «функция возвращает новое
  состояние», как в двух других вариантах.
- `checkpoint_memories` разворачивается через `Option.value_exn` —
  упадёт с исключением, если чекпоинта ещё нет (недостижимо в этом
  прогоне, `best_relationship_loss` стартует с `infinity`, но это
  осознанно не защищено, как и в оригинале).
- Сообщение о чекпоинте не содержит `loss` (`"Чекпоинт сохранён:
  атмосфера идеальная. Веса зафиксированы."` — точная копия Python;
  в двух других файлах в это сообщение добавлено `(loss=...)`, чего в
  оригинале нет), и эмодзи (🚨, 🔄) в `trigger_reset` сохранены —
  в двух других файлах убраны.

## Монадическая композиция — инфиксная нотация
- `Tracker.create` возвращает `'a t Or_error.t` (валидация
  `patience > 0`). В `run`: `let open Or_error in Tracker.create ...
  >>| fun tracker -> ...`.
- `Tracker.reset` и `check_atmosphere`:
  `let open Option in opt >>| f |> value ~default:...`
  вместо ручного `match` или `Option.value_map`.
- Инфикс применён только там, где есть реальная цепочка шагов; простую
  композицию функций в монаду не заворачивали — см. комментарии в
  файле про "где необходимо".
- Локальный open — только через `let open M in ...`, не через
  `M.(expr)`: граница действия видна отдельной строкой, а не сливается
  со скобками выражения (пользовательское предпочтение, см. ниже).
- В `run` используется `(>>|)` (`Or_error.map`), а не `(>>=)`: тело
  после стрелки само уже не производит `Or_error`, оно чистый `unit`.
  Понадобись там ещё один шаг, способный упасть (второй
  `Tracker.create`), нужен был бы `(>>=)`, чтобы не заворачивать
  `Or_error` в `Or_error`.

## Без if-then-else
Пользователь не любит if-then-else — в функциональном и объектном
(не-naive) файлах его принципиально нет, булевы проверки заменены
комбинаторами, превращающими условие сразу в значение:
- `Tracker.create`: `Result.ok_if_true (patience > 0) ~error:...`
  вместо `if patience <= 0 then ... else ...` — сразу `(unit,
  Error.t) Result.t` = `unit Or_error.t`, домапливается до трекера
  через `(>>|)`. В Python-оригинале `patience <= 0` тихо ломал бы
  логику дальше по потоку (`overfit_counter >= patience` сразу
  истинно) — здесь это явная ошибка на этапе создания, а не скрытый
  баг где-то ниже.
- `Tracker.compare_loss` и `Tracker.patience_status`: числовое
  сравнение (`Float.compare`/`Int.compare`) оборачивается в
  `Ordering.of_int`, `check_atmosphere` ветвится через `match ... with
  Less | Equal | Greater`, а не `if`/`match _ with true | false`
  (последнее — не более чем if в других скобках, тоже не подходит).
  Приём буквально из `ordering.mli` самого Base.
- Сигнатуры (`Result.ok_if_true : bool -> error:'err -> (unit, 'err)
  t`, `Ordering.of_int : int -> t`) сверены по `.mli` в `_opam/lib/`,
  не по памяти — оба реэкспортированы `Core` (свои `result.mli` и
  `ordering.mli` в `_opam/lib/core/`, `include module type of
  Base.*`).
- `marriage_early_stopping_naive.ml` — единственное сознательное
  исключение: там `if` есть намеренно, см. «Архитектура (naive)» выше.

## Вывод текста
`[%string "...%{expr}..."]` (ppx_string, часть ppx_jane) вместо
`Printf.sprintf` с позиционными аргументами. Для числового формата
`%.3f` (ppx_string это не покрывает) — сначала `sprintf "%.3f" loss`,
затем интерполируем уже готовую строку.

## Сборка и запуск
Под-проект использует локальный opam switch (песочница `ocaml/_opam/`)
— зависимости изолированы от глобального switch и от других
OCaml-проектов в рабочей области. Сами зависимости (`core`,
`ppx_jane`) объявлены не вручную, а в `depends` пакета
`marriage_early_stopping.opam` (генерируется из `dune-project`).

Все команды ниже выполняются из этой папки (`cd ocaml`).

Первоначальная настройка (один раз; `make setup-ocaml` из корня
репозитория делает то же самое):
```
opam switch create . 5.3.0 --yes
opam install . --deps-only --with-test --yes   # core, ppx_jane, alcotest — из depends .opam
opam install ocaml-lsp-server ocamlformat --yes   # для редактора, см. ниже
```

Сборка и запуск (все три варианта одной командой `dune build`;
`make demo-ocaml` из корня делает то же самое):
```
dune build
dune exec ./bin/marriage_early_stopping.exe         # функциональный
dune exec ./bin/marriage_early_stopping_oop.exe     # объектный
dune exec ./bin/marriage_early_stopping_naive.exe   # объектный, буквальный порт
```

Локальный switch подхватывается автоматически при `cd` в директорию
`ocaml/` (opam ставит cd-хук в шелл при `opam init`; для fish —
`env_hook.fish`, уже подключён). Если авто-активация не сработала
(вложенный шелл, CI без хука) — явно: `opam exec -- dune build`.

`_opam/` и `_build/` — генерируемые директории, в репозиторий не
входят.

## Тесты
Alcotest, юнит-уровень (не dune cram — этот проект их сознательно не
использует, см. `[[feedback-ocaml-no-cram]]` в памяти). `test/dune`:
`(test (name test_marriage_early_stopping) (libraries core
marriage_early_stopping_lib alcotest))` — раз тестируемая логика
теперь в `marriage_early_stopping_lib`, тест может её просто `open`.

`test/test_marriage_early_stopping.ml` — 11 кейсов в трёх группах
(`functional`/`oop`/`naive`), по каждому варианту: `Tracker.create`
отвергает `patience <= 0` с ожидаемым текстом ошибки, первый день
всегда чекпоинт, счётчик оверфита растёт без сброса, пока не исчерпан
`patience`, сброс восстанавливает чекпоинт и обнуляет счётчик. Группа
`naive` — не про «корректность» (там её сознательно нет), а про то,
что баг оригинала (`patience <= 0` → сброс на каждом оверфит-дне)
воспроизведён и это зафиксировано тестом, а не забыто.

Сравнение событий (`Event.t`) — через `Alcotest.testable`, собранный
из `Event.sexp_of_t` (для читаемого diff при провале) и `Event.equal`
(добавлен `[@@deriving equal]` рядом с уже бывшим `sexp_of` — только
ради тестов, на поведение программы не влияет).

`dune test` (или `make test-ocaml` из корня) — запускает всё сразу.

### Редактор (VS Code + OCaml Platform)
Расширению нужны собственные `ocamllsp` и `ocamlformat-rpc` — а не те,
что стоят в глобальном switch рабочей области. Обе версии (LSP-сервер
и dune, генерирующий merlin-конфиг) должны совпадать, иначе
"incompatible version of Dune"; без `ocamlformat` (>0.21.0, даёт
бинарь `ocamlformat-rpc`) типы при наведении не форматируются.
`.vscode/settings.json` (в корне репозитория) явно фиксирует sandbox
на путь до этой папки:
```json
"ocaml.sandbox": { "kind": "opam", "switch": "/Users/paul/work/ocaml/vs_python/ocaml" }
```
После установки пакетов или пересоздания switch — команда в VS Code
**OCaml: Restart Language Server** (расширение не подхватывает новое
окружение само, пока не перезапустишь ocamllsp-процесс).

## Уже проверено
- 2026-08-10: логика разнесена на `lib/` (три `_core.ml`) + `bin/`
  (тонкие точки входа) ради Alcotest (юнит-тесты не могли `open`
  модуль, зашитый прямо в executable). После разбиения `dune build`
  проходит чисто, `dune exec ./bin/*.exe` для всех трёх бинарников
  даёт тот же вывод, что и до разбиения (сверено `diff` между старым и
  новым прогонами). Добавлен `alcotest {with-test}` в зависимости
  `dune-project`, сигнатуры (`Alcotest.testable`/`check`/`test_case`/
  `run`, `val equal : t -> t -> bool` для `[@@deriving equal]` при
  имени типа `t`) сверены по `.mli`/`.ml`-источникам пакета в
  `_opam/lib/alcotest/`, не по памяти. 11 тестов написаны и
  перепроверены: временная порча одной проверки (ожидаемое значение и
  отдельно — перепутанный `.`/`#` у record/object) действительно роняет
  `dune test` с понятной ошибкой, откат возвращает всё в зелёное.
  Отдельно (по просьбе пользователя, `[[feedback-ocaml-no-cram]]`) от
  этой же задачи убраны добавленные было cram-тесты (`.t`-файлы,
  `(cram ...)` в `test/dune`, `(cram enable)` в `dune-project`) —
  остался только Alcotest.
- 2026-08-10: репозиторий реорганизован — все `.ml`/`dune*`/`.opam`
  перенесены из корня в `ocaml/` (`git mv`), локальный switch удалён и
  создан заново внутри `ocaml/` (переносить `_opam/` перемещением
  файлов не стали — в нём зашиты абсолютные пути, безопаснее
  пересоздать: `opam switch create . 5.3.0`, затем `opam install .
  --deps-only` и `ocaml-lsp-server`/`ocamlformat` заново). После
  переезда `dune build` из `ocaml/` собирает все три бинарника без
  предупреждений, вывод не изменился. `.vscode/settings.json` (в
  корне) обновлён на новый путь switch.
- 2026-08-10: добавлен `marriage_early_stopping_naive.ml` (третий
  executable в той же секции). Черновик сначала собран и прогнан
  отдельно от проекта (`opam exec --switch
  /Users/paul/work/ocaml/vs_python -- dune build` в scratch-директории
  с собственным `dune-project`), затем перенесён как есть. `dune
  build` собирает все три бинарника без предупреждений; штатный вывод
  словесно совпадает с Python-оригиналом (не с двумя другими .ml —
  сообщение о чекпоинте без `loss`, эмодзи сохранены). `patience=0`
  (временная правка + откат) воспроизводит баг оригинала: сброс
  срабатывает на каждом оверфит-дне подряд, а не после `patience`
  дней — так и должно быть для этого файла, это не регрессия.
  `dune exec marriage_early_stopping_naive` по `public_name` работает,
  `marriage_early_stopping.opam` изменений не потребовал.
- 2026-08-10: добавлен `marriage_early_stopping_oop.ml` (второй
  executable в той же секции `(executables ...)`). `dune build`
  собирает оба бинарника без предупреждений; `dune exec
  ./marriage_early_stopping_oop.exe` даёт побайтово тот же вывод, что
  и функциональный вариант; `patience=0` даёт то же сообщение об
  ошибке (проверено той же схемой — временная правка + откат);
  `dune exec marriage_early_stopping_oop` по `public_name` — тоже
  работает. `marriage_early_stopping.opam` не потребовал изменений
  (dune ставит оба бинарника через общий `@install`).
- 2026-08-10, macOS, локальный opam switch (OCaml 5.3.0, `core`
  v0.17.1, `ppx_jane` v0.17.0): `dune build` и `dune exec` через `opam
  exec --` дают тот же вывод, что и ниже — сборка в изолированной
  песочнице подтверждена рабочей.
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
  используется `Error.of_string` (раньше — `Or_error.error_string`
  напрямую, после перехода на `Result.ok_if_true` сообщение оборачивается
  через `~error:(Error.of_string ...)`, текст ошибки не изменился).
- Ветка `Reset_skipped` (сброс без чекпоинта) физически недостижима в
  текущей `daily_logs` — `best_loss` стартует с `infinity`, поэтому
  первый же день всегда становится новым лучшим. Сам комбинатор
  (`let open Option in _ >>| f |> value ~default`) отдельно проверен
  изолированным тестом на None/Some.
- 2026-08-10: переход на без-if-then-else стиль (`Result.ok_if_true`,
  `Ordering.of_int`, `let open ... in`) — пересобрано с нуля, штатный
  прогон даёт побайтово тот же вывод, что и до рефакторинга;
  `patience=0` отдельно перепроверен (временная правка + откат) —
  сообщение об ошибке не изменилось.
