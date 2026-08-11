package marriageearlystopping.oop

sealed trait Event:
  def render: String

case class CheckpointSaved(loss: Double) extends Event:
  def render: String =
    val lossText = "%.3f".formatLocal(java.util.Locale.ROOT, loss)
    s"Чекпоинт сохранён: атмосфера идеальная (loss=$lossText). Веса зафиксированы."

case class OverfitDetected(counter: Int, patience: Int) extends Event:
  def render: String = s"Внимание: замечен оверфит. Счётчик: $counter/$patience"

case object ResetTriggered extends Event:
  def render: String =
    "Критический оверфит! Инициирую сброс до стабильного чекпоинта...\n" +
      "Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается."

case object ResetSkipped extends Event:
  def render: String =
    "Критический оверфит, но сохранённого чекпоинта ещё нет — восстанавливать нечего."

trait Logger:
  def log(message: String): Unit

class StdoutLogger extends Logger:
  def log(message: String): Unit = println(message)

class Presenter(logger: Logger):
  def handle(events: List[Event]): Unit = events.foreach(event => logger.log(event.render))

class DebugPresenter(logger: Logger):
  def handle(events: List[Event]): Unit = events.foreach(event => logger.log(event.toString))

class InvalidPatienceException(message: String) extends IllegalArgumentException(message)

class Tracker(patience: Int = 3):
  if patience <= 0 then
    throw InvalidPatienceException(s"patience должен быть положительным (patience = $patience)")

  private var overfitCounterState: Int = 0
  private var bestLossState: Double = Double.PositiveInfinity
  private var checkpoint: Option[String] = None

  def overfitCounter: Int = overfitCounterState
  def bestLoss: Double = bestLossState

  def checkAtmosphere(dailyLoss: Double, currentState: String): (String, List[Event]) =
    if isNewBest(dailyLoss) then saveCheckpoint(dailyLoss, currentState)
    else registerOverfit(currentState)

  private def isNewBest(dailyLoss: Double): Boolean = dailyLoss < bestLossState

  private def saveCheckpoint(dailyLoss: Double, currentState: String): (String, List[Event]) =
    bestLossState = dailyLoss
    overfitCounterState = 0
    checkpoint = Some(currentState)
    (currentState, List(CheckpointSaved(dailyLoss)))

  private def registerOverfit(currentState: String): (String, List[Event]) =
    overfitCounterState += 1
    val overfitEvent = OverfitDetected(overfitCounterState, patience)
    if !patienceExhausted then (currentState, List(overfitEvent))
    else triggerReset(currentState, overfitEvent)

  private def patienceExhausted: Boolean = overfitCounterState >= patience

  private def triggerReset(currentState: String, overfitEvent: Event): (String, List[Event]) =
    overfitCounterState = 0
    checkpoint match
      case None        => (currentState, List(overfitEvent, ResetSkipped))
      case Some(state) => (state, List(overfitEvent, ResetTriggered))

@main def run(): Unit =
  try
    val dailyLogs = List(
      (0.9, "холодный ужин в тишине"),
      (0.4, "вечер с сериалом и чаем"),
      (0.6, "спор из-за посуды"),
      (0.7, "молчанка"),
      (0.8, "снова молчанка")
    )
    val tracker = Tracker(patience = 3)
    val presenter = Presenter(StdoutLogger())
    val debugPresenter = DebugPresenter(StdoutLogger())

    var events: List[Event] = Nil
    for (dailyLoss, state) <- dailyLogs do
      val (_, dayEvents) = tracker.checkAtmosphere(dailyLoss, state)
      events = dayEvents
      presenter.handle(dayEvents)
    debugPresenter.handle(events)
  catch case e: InvalidPatienceException => System.err.println(s"Ошибка: ${e.getMessage}")
