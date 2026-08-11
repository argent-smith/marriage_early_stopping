package marriageearlystopping.naive

class RelationshipState(var description: String):
  def copy(): RelationshipState = RelationshipState(description)
  def load(other: RelationshipState): Unit = description = other.description
  override def toString: String = description

class Tracker(patience: Int = 3):
  var overfitCounter: Int = 0
  var bestRelationshipLoss: Double = Double.PositiveInfinity
  var checkpointMemories: RelationshipState = null

  def checkAtmosphere(dailyLoss: Double, currentState: RelationshipState): Unit =
    if dailyLoss < bestRelationshipLoss then
      bestRelationshipLoss = dailyLoss
      overfitCounter = 0
      checkpointMemories = currentState.copy()
      println("Чекпоинт сохранён: атмосфера идеальная. Веса зафиксированы.")
    else
      overfitCounter += 1
      println(s"Внимание: замечен оверфит. Счётчик: $overfitCounter/$patience")
      if overfitCounter >= patience then triggerReset(currentState)

  def triggerReset(currentState: RelationshipState): Unit =
    println("🚨 Критический оверфит! Инициирую сброс до стабильного чекпоинта...")
    currentState.load(checkpointMemories)
    overfitCounter = 0
    println("🔄 Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается.")

@main def run(): Unit =
  val tracker = Tracker(3)
  val dailyLogs = List(
    (0.9, "холодный ужин в тишине"),
    (0.4, "вечер с сериалом и чаем"),
    (0.6, "спор из-за посуды"),
    (0.7, "молчанка"),
    (0.8, "снова молчанка")
  )
  for (dailyLoss, state) <- dailyLogs do tracker.checkAtmosphere(dailyLoss, RelationshipState(state))
