# marriage_early_stopping/scala — контекст под-проекта

Три Scala-варианта одного и того же сценария (см. корневой
[../CLAUDE.md](../CLAUDE.md) и [../ocaml/CLAUDE.md](../ocaml/CLAUDE.md),
[../python/CLAUDE.md](../python/CLAUDE.md), [../ruby/CLAUDE.md](../ruby/CLAUDE.md)
для остальных девяти портов и общей картины). Та же трёхчастная схема
сравнения: naive / OOP+SOLID / FP.

Каждый файл — свой `package` (`marriageearlystopping.naive`/`.oop`/`.fp`)
по той же причине, что и в Ruby: все три файла компилируются и
тестируются в одном процессе (`scala-cli test .` разом видит `src/` и
`test/`), одноимённые верхнеуровневые типы (`Tracker`, `Event`,
`StdoutLogger`, ...) в разных файлах без разных пакетов конфликтовали
бы.

## Почему scala-cli, а не sbt/Mill

Явный выбор пользователя после сравнения трёх вариантов сборки. Все
три официально поддержаны Metals (VS Code) как BSP-сервер, но не
одинаково гладко:

- **sbt** — самая обкатанная связка с Metals исторически (sbt-BSP
  плагин делался в паре с Metals с самого начала), но требует
  отдельного `build.sbt` и медленнее стартует.
- **Mill** — быстрее sbt, но интеграция с Metals более шероховатая:
  обычно нужен явный шаг `mill mill.bsp.BSP/install`, периодически
  случается рассинхрон версий Mill/Metals.
- **scala-cli** (выбран) — самая безболезненная интеграция: Metals
  умеет автогенерировать BSP-конфиг для scala-cli-проекта одним
  кликом, без отдельного билд-файла вообще — версия языка и
  зависимости объявляются `//> using`-директивами прямо в
  `project.scala`/исходниках. С 2024 года это же ядро — под именем
  просто `scala` — официальный CLI языка (`scala run`/`scala test`
  эквивалентны `scala-cli run`/`scala-cli test`).

`.bsp/` и `.scala-build/` — генерируются самим scala-cli при первом
`compile`/`run`/`test` (BSP-конфиг для Metals и кеш инкрементальной
компиляции соответственно), в репозиторий не входят (см. `.gitignore`
в корне) — `.bsp/scala-cli.json` содержит абсолютные пути конкретной
машины, непереносим между машинами/пользователями; Metals
регенерирует его сам при открытии проекта. `.metals/` (лог и
H2-индекс символов самого Metals) генерируется туда, что VS Code в
моменте считает корнем workspace — в этом репозитории это оказался
корень `vs_python/`, а не `scala/`, поэтому запись про игнорирование
добавлена в корневой `.gitignore`, а не в отдельный `.gitignore`
внутри `scala/`.

## Топовая версия языка и зависимостей

По прямой просьбе пользователя — не LTS, а самая свежая на момент
работы стабильная версия каждого компонента, сверено по
`maven-metadata.xml` на Maven Central (`org/scala-lang/scala3-compiler_3`,
`org/typelevel/cats-core_3`, `org/scalameta/munit_3`,
`org/scalameta/scalafmt-core_2.13`), не по памяти и не по дефолту
локально установленного `scala-cli` (он в моменте был на версию ниже
собственного последнего релиза — `brew upgrade scala-cli` понадобился
отдельно):
- Scala **3.8.4** (`//> using scala 3.8.4` в `project.scala`) — Next-линия,
  не LTS 3.3.x: 3.9.0 на момент работы был ещё только в RC (`3.9.0-RC5`
  в `maven-metadata.xml`), поэтому не взят.
- `cats-core` **2.13.0** — единственная не-stdlib зависимость, нужна
  только `MarriageEarlyStoppingFp.scala` (см. «Архитектура (FP)»
  ниже), но объявлена в `project.scala` (глобально для проекта), а не
  scoped-директивой в самом файле — по итогу лучше следовать
  собственной рекомендации scala-cli («Using directives detected in
  multiple files... keep them centralized»), чем держать зависимость
  ближе к месту использования. Та же ситуация, что с `dry-*` в
  `ruby/Gemfile` — формально общие зависимости, а не только `_fp.rb`.
- `munit` **1.3.5** (`//> using test.dependency`) — тестовый фреймворк
  из официального Scala Toolkit, ближайший аналог по духу к
  Alcotest/pytest/RSpec: минималистичные ассерты, не DSL для
  спецификаций.
- `scalafmt` **3.11.5**, dialect `scala3` — см. «Линт».

## Файлы (все в этой папке)
- `project.scala` — `//> using`-директивы на весь проект (версия
  Scala, зависимости). scala-cli сам нормализовал `dep`/`test.dep` в
  каноничные `dependency`/`test.dependency` и добавил
  `// Main`/`// Test`-комментарии при первом `scala-cli fix . --power`
  (см. «Уже проверено»).
- `src/MarriageEarlyStoppingNaive.scala` — буквальный порт: `if`/`else`,
  `println` прямо в методах, никакой валидации `patience`, эмодзи (🚨,
  🔄), `checkpointMemories: RelationshipState = null` — та же точка
  сравнения, что и `marriage_early_stopping_naive.rb`/`.ml` и
  Python-оригинал. `RelationshipState` — тот же мини-шим с
  `copy()`/`load(other)`, нужен по той же причине, что и в остальных
  языках: `current_state` в исходном псевдокоде предполагает объект с
  этими методами, а не голую строку.
- `src/MarriageEarlyStoppingOop.scala` — SOLID + полиморфизм, см.
  «Архитектура (OOP)» ниже.
- `src/MarriageEarlyStoppingFp.scala` — `cats`, композиция маленьких
  классов, см. «Архитектура (FP)» ниже.
- `test/*.test.scala` — munit, см. «Тесты» ниже. Суффикс `.test.scala`
  и расположение в `test/` — то, как scala-cli отличает тестовые
  источники от основных (без директив, просто по имени/пути файла).
- `.scalafmt.conf` / `.scalafix.conf` — см. «Линт».

## Архитектура (OOP + SOLID, src/MarriageEarlyStoppingOop.scala)
- `Event` — `sealed trait` с абстрактным `def render: String`,
  `CheckpointSaved`/`OverfitDetected`/`ResetTriggered`/`ResetSkipped` —
  `case class`/`case object`, каждый переопределяет `render`.
  Полиморфизм вместо ветвления по типу события — тот же приём, что
  `ABC` в Python и `Data.define`-блоки в Ruby, здесь — идиоматичный для
  Scala 3 sealed-trait-иерархия (плюс `case class`/`case object` дают
  `render`-переопределение и бесплатные `equals`/`toString` сразу).
- `Logger` — `trait` с одним методом `log`, `StdoutLogger` — реализация.
  `Presenter`/`DebugPresenter` — конструкторская инъекция `Logger`.
- `Tracker` — mutable класс с приватными `var`-полями
  (`overfitCounterState`, `bestLossState`, `checkpoint`), публичные
  `def overfitCounter`/`def bestLoss` — read-only аксессоры,
  добавлены специально для тестов (тот же приём, что и в OCaml/Python/
  Ruby OOP-вариантах — не трогать инкапсуляцию мутацией снаружи).
  `checkAtmosphere` — двухветочный if-выражение
  (`isNewBest` → `saveCheckpoint`/`registerOverfit`), `registerOverfit`
  сам не трогает reset — делегирует `triggerReset`, если
  `patienceExhausted`. "Tell, don't ask": снаружи вызывается только
  `checkAtmosphere`.
- Валидация `patience` — `throw InvalidPatienceException(...)`
  (наследник `IllegalArgumentException`) в теле класса (выполняется
  при конструировании, до того как объект вообще существует). Тот же
  механизм, что в `_oop.py`/`_oop.rb`; отличие от `_fp.scala` — там та
  же проверка через `Either`/`Validated`, без исключений.

## Архитектура (FP, src/MarriageEarlyStoppingFp.scala)
`cats-core` — та же организация, что `returns` для Python и `dry-rb`
для Ruby: библиотека FP-абстракций поверх уже мощного stdlib
(`Either`/`Option` в Scala и так родные типы с `.map`/`.flatMap`/
for-comprehension — `cats` здесь используется намеренно узко, только
там, где стандартная библиотека не даёт готового комбинатора, а не
чтобы заменить `Either`/`Option` целиком):

- **Данные — `case class`/`case object`, ничего больше.**
  `CheckpointSaved`/`OverfitDetected`/`ResetTriggered`/`ResetSkipped`/
  `Tracker` — только поля, ни одного метода с поведением (в отличие от
  `_oop.scala`, где `Event.render` — намеренно поведение на данных,
  это разница между двумя файлами, не недосмотр). Обновление полей —
  `tracker.copy(поле = значение)`, бесплатный метод `case class` —
  прямой аналог `tracker.new(...)` у `Dry::Struct` в Ruby,
  `dataclasses.replace`/`.model_copy` в Python, `{ t with ... }` в
  OCaml.
- **Поведение — маленькие классы с одной обязанностью.**
  `TrackerFactory#create` (валидация + создание), `CheckAtmosphere#apply`
  (переход состояния), `Presenter#handle`/`DebugPresenter#handle`
  (вывод, ровно как в `_oop.scala`), `Simulation#call` (оркестрация).
  Не модуль функций и не статические методы на companion object —
  реальные классы с конструкторской инъекцией зависимостей (см.
  `[[feedback-fp-composition-style]]` в памяти — тот же принцип,
  выведенный на Ruby в этой же серии портов, применён здесь с самого
  начала, а не через отвергнутые промежуточные версии).
- **`Simulation` собирает четыре зависимости через конструктор с
  дефолтами** — `TrackerFactory()`/`CheckAtmosphere()`/`Presenter()`/
  `DebugPresenter()` по умолчанию (обычные параметры конструктора Scala
  со значением по умолчанию — не нужен отдельный DI-фреймворк вроде
  `dry-initializer` в Ruby, язык даёт именованные параметры с
  дефолтами из коробки), но их можно подменить в тесте (см. «Тесты» —
  тест на композицию подменяет `presenter`/`debugPresenter` шпионом и
  проверяет, что `Simulation` ничего не печатает напрямую в `stdout`, а
  идёт только через переданный `Logger`).
- **`Logger` — `trait`, как и в `_oop.scala`, не конкретный класс.**
  Первая версия файла типизировала `Presenter`/`DebugPresenter` через
  конкретный `StdoutLogger`, а не через абстракцию — работало (Scala
  позволяет наследоваться от открытого класса), но было архитектурно
  слабее: зависимость от интерфейса, а не от реализации, и здесь тоже
  должна быть настоящей, не «технически подменяемой через
  наследование». Поймано и исправлено до первого коммита, не оставлено
  как исторический артефакт.
- **Валидация — `cats.data.Validated`, не голое `Either.cond`.**
  `PatienceValidator#validate`: `Validated.cond(patience > 0, patience,
  сообщение)`, `TrackerFactory#create` конвертирует через `.toEither` и
  докомпоновывает `.map(...)`. `Validated` здесь — прямой аналог
  `dry-validation`-контракта в Ruby и `returns`-валидации в Python:
  граница, где cats реально используется, а не просто установлена «на
  всякий случай».
- **Монадная композиция — `Either`/`Option`-комбинаторы, не
  unwrap-и-match.** `CheckAtmosphere#apply`:
  `checkpointStep(...).getOrElse(overfitStep(...))` —
  `checkpointStep` возвращает `Option`, что день не стал новым лучшим —
  не «ошибка», а `None` (условие не выполнено), `getOrElse` ленив
  (сигнатура stdlib `Option#getOrElse` берёт аргумент by-name — то же
  свойство, что и `.or { }` в Ruby dry-monads). `reset`:
  `tracker.checkpoint.map(...).getOrElse(...)`, не `match Some/None` —
  тот же приём, что `.fmap`/`.value_or` в Ruby.
- **Fold, не императивный цикл с переприсваиванием.** `Simulation#run`
  — `dailyLogs.foldLeft((tracker, "", List.empty[Event])) { case
  ((currentTracker, _, _), (dailyLoss, state)) => ... }`, побочный
  эффект (`presenter.handle(dayEvents)`) — прямо в теле шага свёртки,
  без отдельного `.tap`, потому что тело fold-шага в Scala и так
  обычная последовательность выражений, а не однострочная функция как
  в Ruby `.tap` — не нужен отдельный комбинатор для «сделать
  побочный эффект и вернуть значение дальше».

## Тесты
munit, `test/`. Запуск: `scala-cli test .` (или `make test-scala` из
корня). 18 тестов в трёх файлах, зеркалят структуру тестов
`ocaml/test/`/`python/tests/`/`ruby/spec/`:
- `MarriageEarlyStoppingNaiveSuite` — `RelationshipState.copy()`/`.load()`
  изолированно, `Tracker(0)` не падает (валидации нет), отдельный тест
  `reproduces the original bug at patience=0` — документирует, а не
  «исправляет» баг (сброс на первом же оверфит-дне), полный
  демо-сценарий через захват `stdout` (`scala.Console.withOut`).
- `MarriageEarlyStoppingOopSuite` — `InvalidPatienceException` на
  `patience <= 0` (через `intercept[...]`), переходы
  checkpoint/overfit/reset, сравнение событий через `assertEquals`
  (`case class`/`case object` сравнимы по значению из коробки).
- `MarriageEarlyStoppingFpSuite` — по классам (`TrackerFactory`,
  `CheckAtmosphere`, `Simulation`), не по функциям: валидация
  patience, обновление полей `Tracker` при чекпоинте, переходы
  checkpoint/overfit/reset (включая физически недостижимый через
  публичный сценарий `ResetSkipped` — тестируется напрямую через
  `Tracker(..., checkpoint = None)`, сконструированный руками, тот же
  приём, что и в OCaml/Ruby). Отдельный тест на саму композицию:
  `Simulation(presenter = ..., debugPresenter = ...)` со
  шпионом-`Logger` вместо `StdoutLogger` — доказывает, что `Simulation`
  реально уважает внедрённые зависимости.

Все три файла содержат тест полного демо-сценария через
`scala.Console.withOut(captured)(run())` — прямой аналог `capsys` в
pytest, `output(...).to_stdout` в RSpec, golden-файлов в dune cram
(которого в проекте нет, см. `[[feedback-ocaml-no-cram]]`).

Механизм проверен: временная порча одной проверки
(`assertEquals(tracker.overfitCounter, 2)` →
`assertEquals(tracker.overfitCounter, 999)`) реально роняет
`scala-cli test .` с понятным diff'ом (`munit.ComparisonFailException`,
`=> Obtained` / цветной diff), откат возвращает всё в зелёное.

## Линт
`scalafmt` (форматирование) + `scalafix` (линт/рефакторинг), оба через
сам scala-cli, отдельно ничего не ставится:
- `scala-cli fmt .` — применить форматирование, `scala-cli fmt --check .`
  — проверить без изменений (`make fmt`/`make lint` из корня делают то
  же самое). `.scalafmt.conf`: `version = 3.11.5`, `runner.dialect =
  scala3`, `maxColumn = 110`.
- `scala-cli fix . --power` — применить scalafix-правила,
  `scala-cli fix --check . --power` — проверить без изменений. Флаг
  `--power` обязателен — команда `fix` официально экспериментальная
  (сам scala-cli об этом предупреждает при каждом запуске). `--check`
  проверяет только scalafix-правила, не встроенные (built-in) —
  сообщение `'--check' is not yet supported for built-in rules`,
  зафиксировано эмпирически, не в документации.
- `.scalafix.conf`: `DisableSyntax` с точечно включёнными
  `noAsInstanceOf`/`noXml`. Не включены `noVars`/`noNulls` — они
  конфликтовали бы с намеренным дизайном `_naive.scala` (mutable `var`,
  `checkpointMemories: RelationshipState = null` — часть точки
  сравнения «наивности», а не недосмотр); включать линт-правило,
  которое приходится тут же глушить построчными исключениями ради
  единственного файла, хуже, чем просто не включать его глобально —
  тот же принцип, что у `Metrics/MethodLength`-исключений в
  `ruby/.rubocop.yml`.

## Уже проверено
- 2026-08-11: локально установленный `scala-cli` (1.12.5) был на одну
  минорную версию старше собственного актуального релиза — обновлён
  `brew upgrade scala-cli` до 1.16.0 (Scala по умолчанию сразу стала
  3.8.4). Актуальность версий Scala/`cats-core`/`munit`/`scalafmt`
  сверена по `maven-metadata.xml` на Maven Central напрямую (`curl`),
  не по документации и не по дефолту локального инструмента — дефолт
  до обновления показывал `3.8.2`/`3.8.3` в разных командах
  (`scala-cli version` и `scala version` расходились), что и стало
  сигналом проверить отдельно.
- 2026-08-11: реальный баг, а не гипотетический — `f"...loss=$loss%.3f..."`
  печатал `0,900` (запятая) вместо `0.900` на этой машине: `f""`-интерполятор
  и `String.format`/`.format(...)` в Scala/Java по умолчанию берут
  `Locale.getDefault()`, а не `Locale.ROOT`, и локаль этой машины
  форматирует `Double` с запятой как десятичным разделителем. Ломало
  сравнение вывода со всеми остальными языками репозитория (везде
  `0.900`, точка). Исправлено на `"%.3f".formatLocal(java.util.Locale.ROOT,
  loss)` в обоих файлах, где встречается (`_oop.scala`, `_fp.scala`) —
  `_naive.scala` не затронут, там `loss` в сообщении о чекпоинте нет
  (см. «Файлы»). Поймано до написания тестов запуском `scala-cli run`
  и визуальной сверкой с выводом остальных языков — не полагались на
  память о том, что `%.3f` «просто работает».
  Урок общий не только для Scala: любое форматирование чисел с
  плавающей точкой в текст для сравнения между языками должно явно
  фиксировать locale/culture, а не полагаться на дефолт окружения,
  который на CI/другой машине/у другого разработчика может отличаться.
- 2026-08-11: первая версия `_fp.scala` типизировала
  `Presenter`/`DebugPresenter` через конкретный класс `StdoutLogger`, а
  не через `trait Logger` (в отличие от `_oop.scala`, где `Logger` —
  абстракция с самого начала). Поймано при сверке с `_oop.scala` перед
  написанием тестов, не тестами постфактум — исправлено на `trait
  Logger` + `StdoutLogger extends Logger`, `Presenter`/`DebugPresenter`
  принимают `Logger`.
- 2026-08-11: первая версия `project.scala` объявляла `cats-core` через
  scoped `//> using dep` прямо в `MarriageEarlyStoppingFp.scala` (чтобы
  зависимость была видна только там, где используется — возможность,
  которой нет у остальных языков репозитория, каждый из них тянет
  зависимости на весь под-проект). `scala-cli compile .` предупредил:
  «Using directives detected in multiple files... recommended to keep
  them centralized in project.scala». Последовали рекомендации самого
  инструмента вместо теоретически более узкой области видимости —
  перенесено в `project.scala`.
- 2026-08-11: `scala-cli test .` — 18/18 (8 fp + 5 oop + 5 naive),
  `scala-cli fmt --check .` и `scala-cli fix --check . --power` — оба
  чисто, `scala-cli run . --main-class marriageearlystopping.<naive|oop|fp>.run`
  для всех трёх вариантов даёт тот же текст, что и остальные девять
  портов (после исправления locale-бага выше); механизм тестов
  перепроверен порчей одной проверки (см. «Тесты»).
