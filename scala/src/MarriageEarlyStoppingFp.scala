package marriageearlystopping.fp

import cats.data.Validated

sealed trait Event
case class CheckpointSaved(loss: Double) extends Event
case class OverfitDetected(counter: Int, patience: Int) extends Event
case object ResetTriggered extends Event
case object ResetSkipped extends Event

case class Tracker(
    patience: Int,
    overfitCounter: Int = 0,
    bestLoss: Double = Double.PositiveInfinity,
    checkpoint: Option[String] = None
)

class PatienceValidator:
  def validate(patience: Int): Validated[String, Int] =
    Validated.cond(patience > 0, patience, s"patience должен быть положительным (patience = $patience)")

class TrackerFactory(validator: PatienceValidator = PatienceValidator()):
  def create(patience: Int = 3): Either[String, Tracker] =
    validator.validate(patience).toEither.map(validPatience => Tracker(patience = validPatience))

class CheckAtmosphere:
  def apply(tracker: Tracker, dailyLoss: Double, currentState: String): (Tracker, String, List[Event]) =
    checkpointStep(tracker, dailyLoss, currentState).getOrElse(overfitStep(tracker, currentState))

  private def checkpointStep(
      tracker: Tracker,
      dailyLoss: Double,
      currentState: String
  ): Option[(Tracker, String, List[Event])] =
    Option.when(dailyLoss < tracker.bestLoss) {
      val updated = saveCheckpoint(tracker, dailyLoss, currentState)
      (updated, currentState, List(CheckpointSaved(dailyLoss)))
    }

  private def overfitStep(tracker: Tracker, currentState: String): (Tracker, String, List[Event]) =
    val bumped = bumpOverfit(tracker)
    val overfitEvent = OverfitDetected(bumped.overfitCounter, bumped.patience)
    if bumped.overfitCounter < bumped.patience then (bumped, currentState, List(overfitEvent))
    else
      val (resetTracker, newState, resetEvent) = reset(bumped, currentState)
      (resetTracker, newState, List(overfitEvent, resetEvent))

  private def saveCheckpoint(tracker: Tracker, dailyLoss: Double, currentState: String): Tracker =
    tracker.copy(bestLoss = dailyLoss, overfitCounter = 0, checkpoint = Some(currentState))

  private def bumpOverfit(tracker: Tracker): Tracker =
    tracker.copy(overfitCounter = tracker.overfitCounter + 1)

  private def reset(tracker: Tracker, currentState: String): (Tracker, String, Event) =
    val resetTracker = tracker.copy(overfitCounter = 0)
    tracker.checkpoint
      .map(state => (resetTracker, state, ResetTriggered))
      .getOrElse((resetTracker, currentState, ResetSkipped))

trait Logger:
  def log(message: String): Unit

class StdoutLogger extends Logger:
  def log(message: String): Unit = println(message)

class Presenter(logger: Logger = StdoutLogger()):
  def handle(events: List[Event]): Unit = events.foreach(event => logger.log(render(event)))

  private def render(event: Event): String = event match
    case CheckpointSaved(loss) =>
      val lossText = "%.3f".formatLocal(java.util.Locale.ROOT, loss)
      s"Чекпоинт сохранён: атмосфера идеальная (loss=$lossText). Веса зафиксированы."
    case OverfitDetected(counter, patience) =>
      s"Внимание: замечен оверфит. Счётчик: $counter/$patience"
    case ResetTriggered =>
      "Критический оверфит! Инициирую сброс до стабильного чекпоинта...\n" +
        "Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается."
    case ResetSkipped =>
      "Критический оверфит, но сохранённого чекпоинта ещё нет — восстанавливать нечего."

class DebugPresenter(logger: Logger = StdoutLogger()):
  def handle(events: List[Event]): Unit = events.foreach(event => logger.log(event.toString))

class Simulation(
    trackerFactory: TrackerFactory = TrackerFactory(),
    checkAtmosphere: CheckAtmosphere = CheckAtmosphere(),
    presenter: Presenter = Presenter(),
    debugPresenter: DebugPresenter = DebugPresenter()
):
  private val dailyLogs = List(
    (0.9, "холодный ужин в тишине"),
    (0.4, "вечер с сериалом и чаем"),
    (0.6, "спор из-за посуды"),
    (0.7, "молчанка"),
    (0.8, "снова молчанка")
  )

  def call(): Either[String, Unit] = trackerFactory.create(patience = 3).map(run)

  private def run(tracker: Tracker): Unit =
    val (_, _, events) = dailyLogs.foldLeft((tracker, "", List.empty[Event])) {
      case ((currentTracker, _, _), (dailyLoss, state)) =>
        val (newTracker, newState, dayEvents) = checkAtmosphere(currentTracker, dailyLoss, state)
        presenter.handle(dayEvents)
        (newTracker, newState, dayEvents)
    }
    debugPresenter.handle(events)

@main def run(): Unit =
  Simulation().call().left.foreach(error => System.err.println(s"Ошибка: $error"))
