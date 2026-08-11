package marriageearlystopping.fp

class MarriageEarlyStoppingFpSuite extends munit.FunSuite:
  test("TrackerFactory rejects patience <= 0") {
    val result = TrackerFactory().create(patience = 0)
    assertEquals(result, Left("patience должен быть положительным (patience = 0)"))
  }

  test("TrackerFactory.create defaults to a fresh Tracker") {
    val result = TrackerFactory().create(patience = 3)
    assertEquals(result, Right(Tracker(patience = 3)))
  }

  test("checkpoint updates best_loss, resets the counter, and stores the state") {
    val tracker = Tracker(patience = 3)
    val (newTracker, _, _) = CheckAtmosphere()(tracker, 0.9, "день 1")
    assertEquals(newTracker.bestLoss, 0.9)
    assertEquals(newTracker.overfitCounter, 0)
    assertEquals(newTracker.checkpoint, Some("день 1"))
  }

  test("the first day is always a checkpoint") {
    val tracker = Tracker(patience = 3)
    val (_, _, events) = CheckAtmosphere()(tracker, 0.9, "день 1")
    assertEquals(events, List(CheckpointSaved(0.9)))
  }

  test("reset restores the checkpointed state") {
    val afterCheckpoint = Tracker(patience = 1, bestLoss = 0.5, checkpoint = Some("хороший день"))
    val (_, state, events) = CheckAtmosphere()(afterCheckpoint, 1.0, "плохой день")
    assertEquals(state, "хороший день")
    assertEquals(events, List(OverfitDetected(1, 1), ResetTriggered))
  }

  test("reset without a checkpoint yet is skipped") {
    val neverCheckpointed = Tracker(patience = 1, bestLoss = 0.5, checkpoint = None)
    val (_, state, events) = CheckAtmosphere()(neverCheckpointed, 1.0, "плохой день")
    assertEquals(state, "плохой день")
    assertEquals(events, List(OverfitDetected(1, 1), ResetSkipped))
  }

  test("Simulation respects injected presenter/debugPresenter instead of printing directly") {
    val logged = scala.collection.mutable.ListBuffer.empty[String]
    class SpyLogger extends Logger:
      def log(message: String): Unit = logged += message
    val spy = SpyLogger()
    val simulation = Simulation(presenter = Presenter(spy), debugPresenter = DebugPresenter(spy))

    val captured = new java.io.ByteArrayOutputStream()
    scala.Console.withOut(captured)(simulation.call())

    assertEquals(captured.toString, "")
    assert(logged.nonEmpty)
  }

  test("full demo scenario matches the documented stdout") {
    val captured = new java.io.ByteArrayOutputStream()
    scala.Console.withOut(captured)(run())
    val expected = List(
      "Чекпоинт сохранён: атмосфера идеальная (loss=0.900). Веса зафиксированы.",
      "Чекпоинт сохранён: атмосфера идеальная (loss=0.400). Веса зафиксированы.",
      "Внимание: замечен оверфит. Счётчик: 1/3",
      "Внимание: замечен оверфит. Счётчик: 2/3",
      "Внимание: замечен оверфит. Счётчик: 3/3",
      "Критический оверфит! Инициирую сброс до стабильного чекпоинта...",
      "Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается.",
      "OverfitDetected(3,3)",
      "ResetTriggered"
    ).mkString("", "\n", "\n")
    assertEquals(captured.toString, expected)
  }
