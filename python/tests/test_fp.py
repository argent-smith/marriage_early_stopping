from returns.maybe import Nothing, Some
from returns.result import Failure, Success

from marriage_early_stopping_fp import (
    CheckpointSaved,
    OverfitDetected,
    ResetTriggered,
    Tracker,
    check_atmosphere,
    run,
)


def test_create_rejects_non_positive_patience():
    result = Tracker.create(patience=0)
    assert result == Failure("patience должен быть положительным (patience = 0)")


def test_create_accepts_positive_patience():
    assert Tracker.create(patience=3) == Success(Tracker(patience=3))


def test_first_day_is_always_a_checkpoint():
    tracker = Tracker(patience=3)
    new_tracker, state, events = check_atmosphere(tracker, daily_loss=0.9, current_state="day1")
    assert state == "day1"
    assert events == [CheckpointSaved(0.9)]
    assert new_tracker.best_loss == 0.9
    assert new_tracker.checkpoint == Some("day1")
    # tracker, переданный на вход, не изменился — иммутабельность.
    assert tracker.best_loss == float("inf")


def test_overfit_counter_increments_without_reset():
    tracker = Tracker(patience=3).save_checkpoint(loss=0.4, state="best")
    _, _, events = check_atmosphere(tracker, daily_loss=0.6, current_state="worse")
    assert events == [OverfitDetected(1, 3)]


def test_reset_triggered_restores_checkpoint_and_resets_counter():
    tracker = Tracker(patience=2).save_checkpoint(loss=0.4, state="best")
    tracker, _, _ = check_atmosphere(tracker, daily_loss=0.6, current_state="worse-1")
    tracker, state, events = check_atmosphere(tracker, daily_loss=0.7, current_state="worse-2")
    assert state == "best"
    assert events == [OverfitDetected(2, 2), ResetTriggered()]
    assert tracker.overfit_counter == 0


def test_reset_returns_nothing_when_no_checkpoint_yet():
    tracker = Tracker(patience=1)
    _, restored = tracker.reset()
    assert restored == Nothing


def test_demo_scenario_output(capsys):
    result = run()
    assert result == Success(None)
    captured = capsys.readouterr()
    assert captured.out == (
        "Чекпоинт сохранён: атмосфера идеальная (loss=0.900). Веса зафиксированы.\n"
        "Чекпоинт сохранён: атмосфера идеальная (loss=0.400). Веса зафиксированы.\n"
        "Внимание: замечен оверфит. Счётчик: 1/3\n"
        "Внимание: замечен оверфит. Счётчик: 2/3\n"
        "Внимание: замечен оверфит. Счётчик: 3/3\n"
        "Критический оверфит! Инициирую сброс до стабильного чекпоинта...\n"
        "Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается.\n"
        "OverfitDetected(counter=3, patience=3)\n"
        "ResetTriggered()\n"
    )


def test_error_path_prints_message(capsys):
    import marriage_early_stopping_fp as m

    original_run = m.run
    m.run = lambda: m.Tracker.create(patience=0).map(lambda _: None)
    try:
        m.main()
    finally:
        m.run = original_run
    captured = capsys.readouterr()
    assert captured.err == "Ошибка: patience должен быть положительным (patience = 0)\n"
