package marriageearlystopping.naive

class MarriageEarlyStoppingNaiveSuite extends munit.FunSuite:
  test("RelationshipState.copy() produces an independent snapshot") {
    val original = RelationshipState("вечер с сериалом")
    val snapshot = original.copy()
    original.description = "спор из-за посуды"
    assertEquals(snapshot.description, "вечер с сериалом")
  }

  test("RelationshipState.load(other) overwrites the description") {
    val target = RelationshipState("молчанка")
    val source = RelationshipState("Любимый человек")
    target.load(source)
    assertEquals(target.description, "Любимый человек")
  }

  test("Tracker(0) does not validate patience") {
    val tracker = Tracker(0)
    assertEquals(tracker.overfitCounter, 0)
  }

  test("reproduces the original bug at patience=0: reset fires on the very next overfit day") {
    val tracker = Tracker(0)
    tracker.checkAtmosphere(0.9, RelationshipState("день 1"))
    tracker.checkAtmosphere(1.0, RelationshipState("день 2"))
    assertEquals(tracker.overfitCounter, 0)
  }

  test("full demo scenario matches the documented stdout") {
    val captured = new java.io.ByteArrayOutputStream()
    scala.Console.withOut(captured)(run())
    val expected = List(
      "Чекпоинт сохранён: атмосфера идеальная. Веса зафиксированы.",
      "Чекпоинт сохранён: атмосфера идеальная. Веса зафиксированы.",
      "Внимание: замечен оверфит. Счётчик: 1/3",
      "Внимание: замечен оверфит. Счётчик: 2/3",
      "Внимание: замечен оверфит. Счётчик: 3/3",
      "🚨 Критический оверфит! Инициирую сброс до стабильного чекпоинта...",
      "🔄 Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается."
    ).mkString("", "\n", "\n")
    assertEquals(captured.toString, expected)
  }
