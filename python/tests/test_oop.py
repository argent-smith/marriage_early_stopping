import pytest

from marriage_early_stopping_oop import (
    CheckpointSaved,
    InvalidPatience,
    OverfitDetected,
    ResetTriggered,
    Tracker,
    run,
)


def test_non_positive_patience_raises():
    with pytest.raises(InvalidPatience, match=r"patience = 0"):
        Tracker(patience=0)


def test_negative_patience_raises():
    with pytest.raises(InvalidPatience, match=r"patience = -1"):
        Tracker(patience=-1)


def test_first_day_is_always_a_checkpoint():
    tracker = Tracker(patience=3)
    state, events = tracker.check_atmosphere(daily_loss=0.9, current_state="day1")
    assert state == "day1"
    assert len(events) == 1
    assert isinstance(events[0], CheckpointSaved)


def test_overfit_counter_increments_without_reset():
    tracker = Tracker(patience=3)
    tracker.check_atmosphere(daily_loss=0.4, current_state="best")
    _, events = tracker.check_atmosphere(daily_loss=0.6, current_state="worse")
    assert len(events) == 1
    assert isinstance(events[0], OverfitDetected)
    assert "1/3" in events[0].render()


def test_reset_triggered_after_patience_exhausted_and_restores_checkpoint():
    tracker = Tracker(patience=2)
    tracker.check_atmosphere(daily_loss=0.4, current_state="best")
    tracker.check_atmosphere(daily_loss=0.6, current_state="worse-1")
    state, events = tracker.check_atmosphere(daily_loss=0.7, current_state="worse-2")
    assert state == "best"
    assert len(events) == 2
    assert isinstance(events[1], ResetTriggered)


def test_demo_scenario_output(capsys):
    run()
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
