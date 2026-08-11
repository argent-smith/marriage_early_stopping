package marriageearlystopping.oop

class MarriageEarlyStoppingOopSuite extends munit.FunSuite:
  test("Tracker(patience <= 0) raises InvalidPatienceException") {
    intercept[InvalidPatienceException] {
      Tracker(patience = 0)
    }
  }

  test("the first day is always a checkpoint") {
    val tracker = Tracker(patience = 3)
    val (_, events) = tracker.checkAtmosphere(0.9, "день 1")
    assertEquals(events, List(CheckpointSaved(0.9)))
  }

  test("overfit counter grows without resetting until patience is exhausted") {
    val tracker = Tracker(patience = 3)
    tracker.checkAtmosphere(0.9, "день 1")
    tracker.checkAtmosphere(1.0, "день 2")
    tracker.checkAtmosphere(1.0, "день 3")
    assertEquals(tracker.overfitCounter, 2)
  }

  test("reset restores the checkpointed state and clears the counter") {
    val tracker = Tracker(patience = 1)
    tracker.checkAtmosphere(0.9, "хороший день")
    val (state, events) = tracker.checkAtmosphere(1.0, "плохой день")
    assertEquals(state, "хороший день")
    assertEquals(events, List(OverfitDetected(1, 1), ResetTriggered))
    assertEquals(tracker.overfitCounter, 0)
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
