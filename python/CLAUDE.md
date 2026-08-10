# marriage_early_stopping/python — контекст под-проекта

Три Python-варианта одного и того же сценария (см. корневой
[../CLAUDE.md](../CLAUDE.md) и [../ocaml/CLAUDE.md](../ocaml/CLAUDE.md)
для трёх OCaml-портов и общей картины).

## Файлы (все в этой папке)
- `marriage_early_stopping.py` — оригинал: класс `MarriageEarlyStopping`
  (`__init__`, `check_atmosphere`, `trigger_reset`) — транскрипция
  скриншота 1:1, без изменений. Ниже в том же файле, за явным
  разделителем-комментарием `# === Всё выше — транскрипция...`,
  добавлена обвязка для запуска (её в скриншоте не было):
  - `RelationshipState` — минимальная заглушка с `.copy()`/`.load()`,
    без неё `check_atmosphere`/`trigger_reset` не запустить: оригинал
    вызывает эти методы у `current_state`, но какой у него тип — в
    псевдокоде со скриншота не указано.
  - `if __name__ == "__main__":` — тот же сценарий (5 дней,
    patience=3), что и во всех остальных портах в репозитории.
  - Замечен и явно прокомментирован (не исправлен) баг оригинала:
    `check_atmosphere` ничего не возвращает и не сохраняет
    `current_state` между вызовами — то, что `trigger_reset`
    восстанавливает через `.load(...)`, тут же теряется, потому что
    обвязка на каждой итерации создаёт новый `RelationshipState`.
    Обвязка запускает код как есть, а не чинит его.
- `marriage_early_stopping_oop.py` — рефакторинг в духе SOLID и Sandy
  Metz, см. «Архитектура (OOP + SOLID + Sandy Metz)» ниже.
- `marriage_early_stopping_fp.py` — продвинутый FP-стиль на монадах
  `returns`, см. «Архитектура (FP, returns)» ниже.
- `pyproject.toml` — `dependencies = ["returns>=0.29"]` (нужен только
  для `_fp.py`, `_oop.py` и оригинал — чистый stdlib) плюс
  `[dependency-groups] dev = ["pytest>=9.1.1", "ruff>=0.16.2"]`
  (добавлено через `uv add --dev pytest ruff`, не руками) и
  `[tool.pytest.ini_options]`/`[tool.ruff]` — см. «Тесты» и «Линт и
  форматирование» ниже.
- `uv.lock` — лочит точные версии всего дерева зависимостей
  (`returns`, `pytest`, `ruff` и их собственные зависимости);
  сгенерирован `uv`, в репозиторий входит (в отличие от `.venv/`) —
  это то, что делает установку воспроизводимой, а не просто
  `pip install` "последних версий".
- `tests/` — pytest, см. «Тесты» ниже.

## Архитектура (OOP + SOLID + Sandy Metz, marriage_early_stopping_oop.py)
- `Event` — не dataclass с внешним рендером, а abstract base class
  (`ABC`) с абстрактными `render()`/`render_debug()`; `CheckpointSaved`,
  `OverfitDetected`, `ResetTriggered`, `ResetSkipped` — подклассы,
  каждый переопределяет оба метода. Полиморфизм вместо ветвления по
  типу события ("replace conditional with polymorphism" — ключевой
  приём из POODR Sandy Metz), в отличие от `_fp.py`, где то же самое
  — `match`/`case` по `Union`.
- `Logger` (`ABC`) / `StdoutLogger` — DI через конструктор, как OCaml
  `Logger` module type, только структура интерфейса объектная, а не
  модульная.
  `Presenter`/`DebugPresenter` — тоже конструкторская инъекция
  `Logger`, `handle()` просто вызывает `event.render()`/
  `event.render_debug()` — сам не знает, что за событие.
- `Tracker` — mutable, но маленькими методами (стиль Sandy Metz: почти
  каждый метод — 1–5 строк, обращается максимум к одному-двум полям).
  `check_atmosphere` — трёхстрочный диспетчер (`_is_new_best` →
  `_save_checkpoint`/`_register_overfit`), `_register_overfit` сам не
  трогает reset — делегирует `_trigger_reset`, если `_patience_exhausted()`.
  "Tell, don't ask": внешний код зовёт только `check_atmosphere`, не
  трогает поля `Tracker` напрямую.
- Валидация `patience` — не тихий баг и не `Result`, а исключение
  `InvalidPatience(ValueError)`, поднятое в конструкторе. Это
  идиоматичный Python-механизм ошибок (в отличие от `_fp.py`, где
  та же проверка — через `Result`/`Failure`, без исключений).

## Архитектура (FP, marriage_early_stopping_fp.py)
Монады из `returns` (dry-python) — та же организация и та же
философия, что у `dry-rb` для Ruby (см. пользовательские предпочтения
по Ruby/Rails), только для Python. API сверен через Context7
(`resolve-library-id`/`query-docs` по `/dry-python/returns`) перед
использованием, не по памяти.
- `Tracker` — `@dataclass(frozen=True)`, аналог иммутабельного
  `'a Tracker.t` из OCaml. `checkpoint : Maybe[str]` вместо
  `Optional[str]` — `Nothing`/`Some(x)`, а не `None`/значение.
- `Tracker.create` возвращает `Result[Tracker, str]`:
  `Success(...) if patience > 0 else Failure(...)` — условное
  выражение сразу производит значение нужного типа, а не ветку
  управления (родственно OCaml-стороне: там та же идея через
  `Result.ok_if_true`, тут — через тернарное выражение Python, других
  готовых комбинаторов для этого в `returns` нет).
- `Tracker.reset`: `self.checkpoint.map(lambda state: (...)).value_or((self,
  Nothing))` — прямой аналог OCaml `let open Option in checkpoint >>|
  f |> value ~default:...`; `.map` на `Maybe` — то же, что `(>>|)`.
- `check_atmosphere` — чистая функция, возвращает новый `Tracker`
  (без мутации, `dataclasses.replace`), как в `.ml`, а не как в
  `_oop.py`. Сравнения (`daily_loss < best_loss`,
  `overfit_counter < patience`) — обычный Python `if`: `returns` не
  даёт (и в Python-экосистеме нет устоявшегося) аналога OCaml
  `Ordering.of_int` для этого; вместо `match` на булеве значении
  (плохой стиль что в OCaml, что в Python) оставлен `if`, а `match`
  используется только там, где он реально идиоматичен — на
  `Maybe`/`Result` (`case Some(state): ... case _: ...`,
  `case Failure(error): ... case Success(_): ...`).
  Итог: не буквальная калька OCaml-приёма «никаких if», а перенос
  именно духа — value-oriented обработка ошибок и `Option`, без
  искусственного вытеснения `if` там, где Python не даёт для этого
  хорошего идиоматичного инструмента.
- `run`: `functools.reduce` по `daily_logs`, аккумулятор
  `(Tracker, current_state, events)` — прямой аналог OCaml
  `List.fold`. `Tracker.create(...).map(simulate)` — `.map`, не
  `.bind`, ровно по той же причине, что и `(>>|)` в OCaml `run`:
  `simulate` сама не возвращает `Result`.
- `Event` — `Union` фиксированных `@dataclass(frozen=True)`
  (`CheckpointSaved | OverfitDetected | ResetTriggered | ResetSkipped`)
  — ближайший идиоматичный Python-аналог OCaml-варианта, читаемый
  через структурный `match`/`case`.

## Сборка и запуск
Изолированное окружение — `python/.venv/`, управляется `uv` (в
репозиторий не входит, см. `.gitignore` в корне; `uv.lock` входит).
Раньше был обычный `venv`/`pip`, перешли на `uv` — по явной просьбе
использовать топовые инструменты экосистемы, а не голый stdlib-пайплайн.

Все команды ниже выполняются из этой папки (`cd python`); `make
setup-python`/`demo-python`/`test-python` из корня репозитория — то же
самое одной командой.

Первоначальная настройка (один раз):
```
uv sync
```
`uv sync` сам создаёт `.venv/`, ставит `returns` (из `dependencies`) и
`pytest`/`ruff` (из `[dependency-groups] dev`), строго по версиям из
`uv.lock`.

Запуск:
```
uv run python marriage_early_stopping.py       # оригинал + обвязка
uv run python marriage_early_stopping_oop.py    # SOLID + Sandy Metz
uv run python marriage_early_stopping_fp.py     # монады (returns)
```

## Тесты
`pytest` (`tool.pytest.ini_options` в `pyproject.toml`: `pythonpath =
["."]` — иначе тесты в `tests/` не видят модули верхнего уровня, здесь
нет `src/`-layout и `__init__.py`). Запуск: `uv run pytest` (или `make
test-python` из корня). 17 тестов в трёх файлах:

- `tests/test_oop.py` — `Tracker(patience<=0)` поднимает
  `InvalidPatience` (через `pytest.raises`), первый день всегда
  чекпоинт, счётчик оверфита растёт, сброс восстанавливает состояние.
  Классы событий (`CheckpointSaved` и т.д.) в этом файле — обычные
  классы без `__eq__`, поэтому тесты сравнивают их через `isinstance`
  + `.render()`, а не `==` (боковой эффект дизайна: `_oop.py` не
  получил `__eq__` специально ради тестов — раз в исходнике его нет,
  тест это уважает, а не подстраивает источник под себя).
- `tests/test_fp.py` — то же самое плюс прямые сравнения через `==`
  (доступны бесплатно: `@dataclass` авто-генерирует `__eq__`),
  отдельный тест на иммутабельность (`tracker`, переданный в
  `check_atmosphere`, не меняется — меняется только возвращаемая
  копия), `Failure(...)`/`Success(...)`/`Nothing`/`Some(...)` — прямые
  сравнения контейнеров `returns` (тоже поддерживают `==` из коробки).
- `tests/test_naive.py` — `RelationshipState.copy()`/`.load()`
  проверены изолированно; полный демо-сценарий — через
  `subprocess.run([sys.executable, ...])`, а не импорт: обвязка
  спрятана за `if __name__ == "__main__":`, так что единственный
  честный способ её прогнать — запустить файл по-настоящему, как
  запустил бы пользователь.

Все файлы содержат `test_demo_scenario_output` (`_oop.py`/`_fp.py`
через `capsys`, оригинал — через `subprocess`), byte-for-byte сверенный
с тем, что реально печатает `make demo-python`; при провале виден diff
уже на уровне pytest, без ручного перезапуска скрипта. Механизм
проверен: временно испорченная проверка (`assert state == "best"` →
`"WRONG"`) действительно валит `pytest`, откат возвращает всё в зелёное.

## Линт и форматирование
`ruff` — линт (`[tool.ruff.lint] select = ["E", "F", "I", "UP", "B",
"SIM"]`) и форматирование в одном инструменте, `target-version =
"py311"`. Запуск: `uv run ruff check .` / `uv run ruff format .` (или
`make lint`/`make fmt` из корня).

`marriage_early_stopping.py` исключён из `ruff format`
(`[tool.ruff.format] exclude = [...]`) — это 1:1 транскрипция
скриншота (см. «Файлы» выше), автоформатирование поменяло бы стиль
кавычек (`'inf'` → `"inf"`) в самом оригинальном тексте, а не только в
добавленной обвязке. Из `ruff check` (линт) файл не исключён — там
замечаний и так не было.

## Уже проверено
- 2026-08-10: проект переведён с ручного `venv`+`pip` на `uv`
  (`uv add --dev pytest ruff` — сам создал `[dependency-groups]` и
  `uv.lock`, руками не писали). Добавлены 17 pytest-тестов (см.
  «Тесты») и настроен `ruff` (см. «Линт и форматирование») — оба
  проверены зелёными (`uv run pytest`, `uv run ruff check .`, `uv run
  ruff format --check .`), демо-вывод всех трёх файлов не изменился.
  `ruff format .` реально применён к `_oop.py`/`_fp.py` (2 файла
  переформатированы — только перенос длинных строк, поведение не
  изменилось, проверено повторным запуском и diff'ом вывода);
  `marriage_early_stopping.py` корректно пропущен форматтером
  (остался byte-for-byte тем же).
- 2026-08-10: API `returns` (`Result`/`Success`/`Failure`, `.map`,
  `.bind`, `Maybe`/`Some`/`Nothing`, `.bind_optional`, `.value_or`,
  `pipe`/`flow`, `@safe`) сверено через Context7
  (`/dry-python/returns`) перед написанием `_fp.py` — не по памяти.
- 2026-08-10: `.venv` создан, `returns` 0.29.0 установлен. Все три
  файла запущены (`.venv/bin/python ...`): `_oop.py` и `_fp.py` дают
  побайтово одинаковый текстовый вывод друг другу (то же слово в
  слово сообщение о чекпоинте с `loss=...`, что и в OCaml-вариантах);
  оригинал с обвязкой — тот же сценарий, но текст 1:1 как в
  Python-скриншоте (без `loss` в сообщении о чекпоинте, с эмодзи
  🚨/🔄 — как в `marriage_early_stopping_naive.ml`, не как в двух
  других `.ml`).
- 2026-08-10: путь ошибки `patience<=0` проверен для обоих
  продвинутых вариантов — `_oop.py` поднимает `InvalidPatience`
  (текст сообщения идентичен OCaml-варианту), `_fp.py` даёт
  `Failure(...)`, `main()` печатает то же `Ошибка: ...`. Оригинал с
  обвязкой намеренно НЕ проверялся на `patience<=0` — там баг
  воспроизводится сознательно, тестировать «правильность» нечего.
- 2026-08-10: после переноса файлов из корня репозитория в `python/`
  и пересоздания `.venv` (перемещать venv как есть не стали —
  скрипты вроде `pip` внутри содержат абсолютный shebang на старый
  путь и ломаются при переносе директории; безопаснее пересоздать)
  все три файла перезапущены из нового расположения — вывод не
  изменился.
