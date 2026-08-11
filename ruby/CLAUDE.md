# marriage_early_stopping/ruby — контекст под-проекта

Три Ruby-варианта одного и того же сценария (см. корневой
[../CLAUDE.md](../CLAUDE.md), [../ocaml/CLAUDE.md](../ocaml/CLAUDE.md)
и [../python/CLAUDE.md](../python/CLAUDE.md) для трёх OCaml- и трёх
Python-портов и общей картины). В отличие от Python, здесь нет
«оригинала-скриншота» — все три файла Ruby-специфичны, но следуют той
же трёхчастной схеме сравнения: naive / OOP+SOLID / FP.

Каждый файл — самостоятельный модуль (`module MarriageEarlyStopping;
module Naive|Oop|Fp; ... end; end`). Это не стилистический выбор, а
необходимость: в отличие от Python-файлов (каждый — свой модуль по
факту `import`), plain top-level `class Foo` в двух Ruby-файлах,
загруженных в одном процессе (как это происходит при `rspec`, когда
все `*_spec.rb` требуют свои файлы разом), означало бы, что второй
`require` переоткрывает/конфликтует с первым — оба определяют один и
тот же `::Foo`.

## Файлы (все в этой папке)
- `marriage_early_stopping_naive.rb` — буквальный порт: `if`/`else`,
  `puts` прямо в методах, никакой валидации `patience`, эмодзи (🚨,
  🔄) — та же точка сравнения, что `marriage_early_stopping_naive.ml`
  и Python-оригинал. `RelationshipState` — тот же мини-шim с
  `#copy`/`#load`, что и в `python/marriage_early_stopping.py`
  (`RelationshipState`/`RelationshipState`), нужен по той же причине:
  `current_state` в исходном псевдокоде предполагает объект с этими
  методами, а не голую строку.
- `marriage_early_stopping_oop.rb` — SOLID + Sandy Metz, см.
  «Архитектура (OOP)» ниже.
- `marriage_early_stopping_fp.rb` — монады `dry-monads`, см.
  «Архитектура (FP)» ниже.
- `Gemfile`/`Gemfile.lock` — `dry-monads`, `dry-struct`, `dry-validation`,
  `dry-initializer` в рантайм-зависимостях (все четыре нужны только
  `_fp.rb`), `rspec`/`rubocop` в группе `development, test`.
- `.bundle/config` — `BUNDLE_PATH: "vendor/bundle"`, локальная
  песочница гемов (аналог `ocaml/_opam/`, `python/.venv/`); файл
  закоммичен (в отличие от `vendor/bundle/` самого), чтобы `bundle
  install` сразу ставил гемы в изолированную папку у любого, кто
  клонирует репозиторий, без ручной настройки.
- `.ruby-version` — `4.0.6`, подхватывается `rbenv` при `cd` в папку
  (тот же механизм, что и cd-хук opam для `ocaml/`).
- `.rubocop.yml` — см. «Линт» ниже.
- `spec/` — RSpec, см. «Тесты» ниже.

## Архитектура (OOP + SOLID + Sandy Metz, marriage_early_stopping_oop.rb)
- События — не классы с ручным `#inspect`, а `Data.define(:поля) do
  ... end`: неизменяемые value-объекты с бесплатными `#==` и
  `#inspect` (`#<data CheckpointSaved loss=0.9>`), у каждого свой
  `#render`. Полиморфизм вместо ветвления по типу события — тот же
  приём, что в `python/marriage_early_stopping_oop.py` (там —
  `ABC`-иерархия), здесь — идиоматичный для Ruby `Data.define`
  (появился в 3.2, специально для таких неизменяемых записей).
- `Logger` — не формальный интерфейс/модуль, а duck typing: и
  `Presenter`, и `DebugPresenter` просто ожидают у переданного объекта
  метод `#log`. Формальный `Logger`-модуль с NotImplementedError был
  бы избыточен и не в духе Sandy Metz («предпочитай duck typing
  жёстким интерфейсам там, где контракт и так очевиден по одному
  методу»).
- `Tracker` — mutable, но маленькими методами (POODR: почти каждый
  метод — несколько строк, трогает один-два инстанс-var).
  `check_atmosphere` — двухстрочный диспетчер
  (`new_best?` → `save_checkpoint`/`register_overfit`),
  `register_overfit` сам не трогает reset — делегирует
  `trigger_reset`, если `patience_exhausted?`. "Tell, don't ask":
  снаружи вызывается только `check_atmosphere`.
- Валидация `patience` — `raise InvalidPatienceError` (пользовательский
  класс ошибок, `ArgumentError` под капотом) в конструкторе. Тот же
  механизм, что в `_oop.py` (`InvalidPatience`); отличие от `_fp.rb` —
  там та же проверка через `Failure(...)`, без исключений.
- `overfit_counter`/`best_loss` — публичные read-only методы
  (endless-method, `def overfit_counter = @overfit_counter`, RuboCop
  сразу переписал в `attr_reader`), добавлены специально для тестов —
  чтобы проверять состояние объекта, не трогая инкапсуляцию мутацией
  снаружи.

## Архитектура (FP, marriage_early_stopping_fp.rb)
Четыре гема `dry-rb` сразу (`dry-monads`, `dry-struct`, `dry-validation`,
`dry-initializer`) — та же организация, что упомянута в
пользовательских предпочтениях по Ruby (там речь про общий стиль кода;
здесь — намеренно чистая, до предела доведённая демонстрация
FP-полюса сравнения, как и `_fp.py` на `returns` для Python). API всех
четырёх сверено через Context7 и по исходникам гемов в
`vendor/bundle/`, не по памяти — см. «Уже проверено» за конкретику
(`to_monad` требует `load_extensions`, `Dry::Struct::Value` устарел,
`gt?:` — реальный предикат dry-logic, `option`/`default:` у
dry-initializer ждёт `Proc`, не голое значение).

«Функциональный» здесь не значит «без классов» — значит «данные
неизменяемы, ошибки — значения, а не исключения». Сама архитектура —
это композиция маленьких объектов с одной обязанностью, как и в
`_oop.rb`; разница между двумя файлами не в «классы vs без классов», а
в том, что именно эти классы делают с состоянием и ошибками:

- **Данные — `Dry::Struct`, ничего больше.**
  `CheckpointSaved`/`OverfitDetected`/`ResetTriggered`/`ResetSkipped`/
  `Tracker` — только `attribute`, ни одного метода с поведением.
  `Dry::Struct` (не `Dry::Struct::Value` — устарел с 1.2.0, единственная
  разница была в глубокой заморозке через `ice_nine`, которую сами
  авторы гема считают не стоящей затрат; равенство по значению есть и
  без неё). Обновление полей — `tracker.new(поле: значение)`, метод
  `new`, вызванный на *инстансе* (не на классе) — задокументированное
  поведение самого гема, а не `#with`, как у встроенного `Data` (см.
  `_oop.rb`); разные гемы — разные имена метода с одним и тем же
  смыслом, перепутать легко (см. «Уже проверено»). Дефолты
  (`overfit_counter: 0`, `best_loss: Float::INFINITY`,
  `checkpoint: None()`) — не в отдельной фабричной функции, а прямо на
  `attribute` через `.default(...)`/`.default { ... }` (блок — для
  `None()`, чтобы не делить один незамороженный объект между
  инстансами, dry-types явно предупреждает об этом).
- **Поведение — маленькие классы с одной обязанностью, не методы на
  `Dry::Struct` и не функции модуля.** `TrackerFactory#call` (валидация
  + создание), `CheckAtmosphere#call` (переход состояния),
  `Presenter#handle`/`DebugPresenter#handle` (вывод, ровно как в
  `_oop.rb`), `Simulation#call` (оркестрация). Никакого
  `module_function`/`extend self`/`def self.foo` россыпью — это была
  промежуточная, отвергнутая версия (см. «Уже проверено»): и
  `module_function`, и `extend self` — способы притвориться, что модуль
  — это объект, вместо того чтобы завести объект. `Simulation` реально
  *использует* `TrackerFactory`/`CheckAtmosphere`/`Presenter` как
  зависимости, а не вызывает соседние функции по имени.
- **Зависимости объявлены, а не назначены руками в `initialize`.**
  `extend Dry::Initializer` + `param`/`option` вместо `def
  initialize(x) = @x = x`: `Presenter`/`DebugPresenter` — `param
  :logger` (позиционный, обязательный), `TrackerFactory`/`Simulation`
  — `option :имя, default: -> { ... }` (именованный, с ленивым
  дефолтом — `default:` обязан быть `Proc`, `instance_exec`'ится гемом
  при первом обращении, не голое значение). Побочный эффект — `logger`,
  `contract`, `tracker_factory` и т.д. становятся публичными
  read-методами автоматически, инстанс-переменные (`@logger` и т.п.)
  в теле классов больше не нужны вообще.
- **`Simulation` собирает четыре зависимости через DI с дефолтами** —
  `TrackerFactory.new`/`CheckAtmosphere.new`/`Presenter.new(StdoutLogger.new)`/
  `DebugPresenter.new(StdoutLogger.new)` по умолчанию, но их можно
  подменить в тесте (см. «Тесты» — тест на композицию подменяет
  `presenter`/`debug_presenter` шпионом и проверяет, что `Simulation`
  ничего не печатает напрямую в `$stdout`, а идёт только через
  переданный логгер).

**Валидация — dry-validation, встроена в тот же монадный пайплайн**:
`PatienceContract` — `params { required(:patience).filled(:integer,
gt?: 0) }`, ни одного ручного `rule`/`if` — `gt?` встроенный предикат
dry-logic, схема сама и коэрсит тип, и проверяет знак одной строкой.
`Dry::Validation::Result` (то, что возвращает `contract.call(...)`) —
не то же самое, что `Dry::Monads::Result`, несмотря на одинаковое имя;
мост между ними — `#to_monad`, но он доступен только после
`Dry::Validation.load_extensions(:monads)` (иначе `NoMethodError`).
`TrackerFactory#call` не выковыривает текст ошибки из
`validation.errors` — просто строит собственное сообщение из уже
известного `patience` в `.or { Failure("...") }`: контракт отвечает
только за да/нет, форматирование сообщения — забота вызывающего кода,
не схемы.

**Монадная композиция — везде, где смысл value-oriented, а не только
в местах, требующих Result/Maybe**:
- `CheckAtmosphere#call` — `checkpoint_step(...).or {
  overfit_step(...) }.value!`: `Maybe` использован не только для
  «опционального значения» в привычном смысле, а как способ выразить
  «попробовать А, если не вышло — Б» без `if` — `checkpoint_step`
  возвращает `None()`, если день не стал новым лучшим (это не
  «ошибка» и не «отсутствие», а сознательный выбор представить
  «условие не выполнено» через `Maybe`, раз `overfit_step` гарантированно
  завершается `Some(...)`, `.value!` в конце безопасен).
- `#reset`: `tracker.checkpoint.fmap { ... }.value_or([tracker,
  None()])` — `.fmap`/`.value_or`, не `case/in` на распакованном
  значении.
- Верхний уровень (`if __FILE__ == ...`): `Simulation.new.call.or {
  |error| warn "Ошибка: #{error}" }`, не `case/in Success/Failure`.
- `Simulation#call`: `tracker_factory.call(patience: 3).fmap(method(:run))`
  — `.fmap`, не `.bind` (`run` сам не производит `Dry::Monads::Result`);
  `method(:run)` вместо `{ |tracker| run(tracker) }` — `.fmap` вызывает
  `.()` на любом объекте с этим методом, обёрточный блок был чистым
  зазором ради зазора (point-free-стиль).
- Осталось два места, где `case/in` — не признак «недостаточно
  монадно», а сам факт того, что это pattern matching по данным, а не
  по монаде: сборка `reset_event` внутри `overfit_step` (через
  `.fmap`/`.value_or`, уже не `case`) и `Presenter#render` —
  диспетчеризация по типу `Event`, ровно как `Presenter.render` в
  OCaml/Python `_fp.py`. Монада тут ни при чём — `CheckpointSaved` и
  соседи не `Result`/`Maybe`.
- `Simulation#run` — `DAILY_LOGS.reduce([tracker, "", []]) { |(current_tracker,
  *), (daily_loss, state)| check_atmosphere.call(...).tap { |_, _, events|
  presenter.handle(events) } }`, не `events = []` + `.each` с
  переприсваиванием `tracker` — тот же `reduce`/`fold`, что в OCaml
  `List.fold` и Python `functools.reduce` в `_fp.py`, а не
  императивный цикл с внешней мутируемой переменной (это была правка
  по прямому замечанию — исходная версия «работала», но была
  единственным явно императивным куском в файле, который должен
  показывать FP-полюс). `.tap` — печать (`presenter.handle`) как
  побочный эффект внутри шага свёртки, без лишней локальной
  переменной для «протащить значение дальше»; финальный `*, events =
  ...` — деструктуризация, берём только последний элемент тройки
  (`tracker`/`current_state` после цикла не нужны, как и в
  OCaml/Python-эквивалентах).

## Тесты
RSpec, `spec/`. Запуск: `bundle exec rspec` (или `make test-ruby` из
корня). 20 примеров в трёх файлах, зеркалят структуру тестов
`ocaml/test/`/`python/tests/`:
- `spec/marriage_early_stopping_naive_spec.rb` — `RelationshipState`
  изолированно (`#copy`/`#load`), `Tracker.new(0)` не падает
  (валидации нет), отдельный тест `reproduces the original bug at
  patience=0` — документирует, а не «исправляет» баг (сброс на первом
  же оверфит-дне), полный демо-сценарий через `output(...).to_stdout`.
- `spec/marriage_early_stopping_oop_spec.rb` —
  `InvalidPatienceError` на `patience <= 0`, переходы
  checkpoint/overfit/reset, сравнение событий через `contain_exactly`
  и `eq` (`Data`-объекты сравнимы по значению из коробки).
- `spec/marriage_early_stopping_fp_spec.rb` — три `describe`-группы по
  классам (`TrackerFactory`, `CheckAtmosphere`, `Simulation`), не по
  функциям: `TrackerFactory.new.call` Success/Failure и дефолты полей
  `Tracker`, `CheckAtmosphere.new.call` — иммутабельность (`new_tracker`
  отличается от входного, оригинал не тронут) и переходы
  checkpoint/overfit/reset. Отдельный тест на саму композицию:
  `Simulation.new(presenter: ..., debug_presenter: ...)` с
  логгером-шпионом вместо `StdoutLogger` — доказывает, что
  `Simulation` реально уважает внедрённые зависимости, а не жёстко
  печатает в `$stdout` в обход них.

Все три файла содержат тест полного демо-сценария через RSpec
built-in matcher `output(...).to_stdout` — прямой аналог `capsys` в
pytest и golden-файлов в dune cram (которого в проекте нет, см.
`[[feedback-ocaml-no-cram]]`, — здесь тот же принцип «сверять реальный
stdout», просто через RSpec-идиому, не через отдельный тестовый
фреймворк).

Механизм проверен: временная порча одной проверки (`eq("best")` →
`eq("WRONG")`) реально роняет `rspec` с понятным diff'ом, откат
возвращает всё в зелёное.

## Линт
RuboCop (`.rubocop.yml`, `TargetRubyVersion: 4.0`). Запуск: `bundle
exec rubocop` (без изменений) или `bundle exec rubocop -a`
(автоисправление) — `make lint`/`make fmt` из корня делают то же
самое. Отключены/настроены только те cops, что прямо противоречат
решениям этого проекта, а не «шум»:
- `Style/Documentation` — выключен: класс/модуль без комментария —
  этот проект держит «зачем» в CLAUDE.md, а не в rdoc-комментариях над
  каждым классом (тот же принцип, что и для OCaml, см.
  `[[feedback-ocaml-no-if]]`-соседний файл про перенос документации).
- `Style/FrozenStringLiteralComment` — выключен: не гонимся за magic
  comment в каждом файле ради буквальной строгой иммутабельности строк,
  когда и так нигде не мутируем строки на месте.
- `Metrics/MethodLength` — поднят до 20 (с дефолтных 10): `run`,
  `check_atmosphere`, `render` — цельные демо-сценарии и
  case/when-подобные ветвления по фиксированному, небольшому набору
  событий; дробление ради лимита не добавляет ясности, только
  разбрасывает связанную логику по методам.
- `Style/StringLiterals` — явно `double_quotes` (а не дефолтный RuboCop
  single-quotes-if-no-interpolation): в файле вперемешку строки с
  интерполяцией и без, единый стиль кавычек читается ровнее, чем
  переключение туда-сюда по формальному критерию; так же
  единообразно, как двойные кавычки у `ruff` для Python-файлов в этом
  репозитории.
## Стиль: field punning
Ruby 3.1+: `{daily_loss:}` вместо `{daily_loss: daily_loss}`, когда
локальная переменная (или keyword-параметр метода) называется так же,
как ключ. Применено в `_fp.rb` (`contract.call(patience:)`,
`check_atmosphere.call(tracker, daily_loss:, current_state: state)`) и
`_oop.rb` (`tracker.check_atmosphere(daily_loss:, current_state:
state)`). Не везде, где формально похоже — паннинг работает только для
голого идентификатора, совпадающего с ключом: `current_state: state`
не паннится (имена разные), `counter: tracker.overfit_counter` не
паннится (есть ресивер, а не голая локальная переменная), `loss:
daily_loss` не паннится (тоже разные имена). `case/in
CheckpointSaved(loss:)` в `Presenter#render` — та же идея, но для
деструктуризации при pattern matching, была в этой форме с самого
начала (не отдельная правка).

## Уже проверено
- 2026-08-11: `_fp.rb` прошёл несколько итераций редизайна за один
  заход (цепочка правок от пользователя, каждая — реакция на
  предыдущую попытку). Итоговая архитектура — в «Архитектура (FP)»
  выше; здесь — что именно отвергалось по пути и почему, чтобы не
  наступить на те же грабли снова:
  - **`Dry::Struct::Value` → `Dry::Struct`.** Первый прогон дал
    deprecation warning. По CHANGELOG гема (1.2.0) — единственная
    разница была в глубокой заморозке через `ice_nine`, признана
    авторами не стоящей затрат; `#==` по значению работает и без неё.
  - **`gt?: 0` вместо ручного `rule(:patience) do ... if value <= 0
    ... end`.** Подтверждено эмпирически (`bundle exec ruby -e
    '...'`), не только по документации — `{patience: ["must be
    greater than 0"]}` на провале, `{}` на успехе.
  - **`Dry::Validation::Result#to_monad` требует
    `Dry::Validation.load_extensions(:monads)`** — без него
    `NoMethodError`; найдено чтением
    `dry-validation-*/lib/dry/validation/extensions/monads.rb`, не по
    памяти.
  - **Бизнес-логика на `Tracker` (методы `#save_checkpoint` и т.п.
    прямо на `Dry::Struct`) была отвергнута** («dry-struct — это
    контейнер данных, а не бизнес-логики») — правильно, `Dry::Struct`
    задуман именно как типизированный контейнер, не место для
    поведения.
  - **Первая попытка вынести поведение — модуль с `module_function`,
    затем с `extend self`, затем россыпь `def self.foo` — тоже
    отвергнута** («не меси модули, а компонуй классы и объекты»).
    Дело не в конкретном механизме экспорта метода на модуль
    (`module_function`/`extend self`/`def self.`), а в том, что модуль
    функций — не композиция вообще: нет объектов, которые можно
    инжектить, подменить в тесте, дать им зависимость по умолчанию.
    Итоговая версия — реальные классы (`TrackerFactory`,
    `CheckAtmosphere`, `Presenter`, `DebugPresenter`, `Simulation`),
    `Simulation` их компонует через конструктор.
  - **`build_tracker`-хелпер, вручную расставлявший дефолты полей —
    тоже анти-паттерн**: дефолты — забота типа (`attribute
    :overfit_counter, Types::Strict::Integer.default(0)` и т.п.), не
    отдельной функции. `.default { Dry::Monads::None() }` — блочная
    форма обязательна для `checkpoint`, потому что dry-types
    предупреждает про шаринг незамороженного дефолта между
    инстансами, если передать голое значение.
  - **`extend Dry::Initializer` + `param`/`option`** вместо ручных
    `def initialize(x) = @x = x` — по прямой просьбе. `option
    :имя, default: -> { ... }` — только `Proc`, не голое значение
    (гем делает `instance_exec(&default)`); `param`/`option`
    автоматически дают публичный reader с тем же именем, инстанс-var
    руками больше нигде не нужен.
  - Финально: `bundle exec rspec` — 20/20 (включая новый тест на
    саму композицию — `Simulation` с подменённым `presenter` не
    печатает в `$stdout` напрямую), `bundle exec rubocop` — 0
    замечаний, `patience<=0` перепроверен (временная правка + откат)
    — то же сообщение об ошибке, что и во всех остальных языках.
  - Однострочные (`def foo = expr`) методы применены во всех трёх
    файлах там, где тело — одно выражение и строка не переваливает за
    разумную длину (геттеры, простые преобразования); там, где тело
    реально многошаговое или однострочная форма выходит нечитаемо
    длинной — обычные `def...end`.
- 2026-08-11: Ruby 4.0.6 поставлен через `rbenv install` (после `brew
  upgrade ruby-build` — без этого `rbenv install --list` не видел
  версию новее 4.0.2), закреплён `rbenv local 4.0.6` → `.ruby-version`.
  Bundler сконфигурирован на локальный `vendor/bundle/` (`bundle
  config set --local path vendor/bundle`) — гемы не улетают в
  общесистемный/rbenv-global gem path.
- 2026-08-11: API `dry-monads` (`Success`/`Failure`/`.bind`/`.fmap`,
  `Maybe`/`Some`/`None`/`.fmap`/`.value_or`, pattern matching через
  `case/in`) сверено через Context7 (`/dry-rb/dry-monads`) перед
  написанием `_fp.rb`; точные полные пути классов
  (`Dry::Monads::Maybe::Some`/`::None`,
  `Dry::Monads::Result::Success`/`::Failure`, и их алиасы прямо на
  `Dry::Monads`) — по исходникам самого гема
  (`vendor/bundle/ruby/4.0.0/gems/dry-monads-1.10.0/lib/dry/monads/`),
  не по памяти.
- 2026-08-11: реальная ошибка в процессе разработки `_fp.rb`, ещё на
  той итерации, где `Tracker` был `Data.define`-based (до перехода на
  `Dry::Struct`, см. «Архитектура (FP)») — `#save_checkpoint` вызывал
  `new(...)` вместо `with(...)` (`NoMethodError: undefined method
  'new' for an instance` — Ruby ищет instance-метод `new`, а не
  class-метод `Tracker.new`). Исправлено тогда на `#with` (метод
  `Data` для «копия с изменёнными полями»). Урок пережил саму правку:
  после миграции на `Dry::Struct` полей копирование снова называется
  `new`, но уже как задокументированный instance-метод самого
  `Dry::Struct` (не `#with`) — те же слова «скопировать с изменением
  поля», разные гемы, разные имена метода; см. «Данные — `Dry::Struct`»
  в «Архитектура (FP)» выше, где именно так это и используется сейчас
  (`tracker.new(...)`).
- 2026-08-11: все три файла (`bundle exec ruby ...`) дают тот же
  человекочитаемый текст (`Presenter`/`render`), что и в других
  языках. Debug-вывод (`DebugPresenter`, `#inspect`) у `_oop.rb` и
  `_fp.rb` уже не совпадает побайтово — и это не только про
  module-qualified имя класса. `_oop.rb` печатает `Data#inspect`:
  `#<data MarriageEarlyStopping::Oop::OverfitDetected counter=3,
  patience=3>` (слово `data`, поля через запятую). `_fp.rb` — после
  перехода событий на `Dry::Struct` (см. «Архитектура (FP)») —
  печатает `Dry::Struct#inspect`: `#<MarriageEarlyStopping::Fp::OverfitDetected
  counter=3 patience=3>` (без `data`, поля без запятой). Оба формата
  сверены реальным запуском, не по памяти. `naive.rb` совпадает по
  форме с `marriage_early_stopping_naive.ml` и Python-оригиналом (нет
  `loss` в сообщении о чекпоинте, есть эмодзи).
  `patience<=0` даёт то же сообщение об ошибке в `_oop.rb`/`_fp.rb`
  (временная правка + откат, тот же приём, что и в остальных языках).
- 2026-08-11: RuboCop — после первого прогона (95 замечаний, почти всё
  `Style/StringLiterals` из-за дефолтного single-quotes-стиля) настроен
  `.rubocop.yml`, автоисправление (`-a`) применено там, где безопасно
  (`Style/TrivialAccessors`, `Style/EmptyClassDefinition`,
  `Layout/*`), `Metrics/MethodLength` расширен осознанно (см. «Линт»).
  Финально: `bundle exec rubocop` — 0 замечаний, `bundle exec rspec` —
  19/19, все три демо-сценария перепрогнаны и не изменились после
  автоисправлений.
