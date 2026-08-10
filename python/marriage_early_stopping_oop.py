from __future__ import annotations

import sys
from abc import ABC, abstractmethod


class InvalidPatience(ValueError):
    pass


class Event(ABC):
    @abstractmethod
    def render(self) -> str: ...

    @abstractmethod
    def render_debug(self) -> str: ...


class CheckpointSaved(Event):
    def __init__(self, loss: float) -> None:
        self._loss = loss

    def render(self) -> str:
        return (
            f"Чекпоинт сохранён: атмосфера идеальная (loss={self._loss:.3f}). Веса зафиксированы."
        )

    def render_debug(self) -> str:
        return f"CheckpointSaved(loss={self._loss!r})"


class OverfitDetected(Event):
    def __init__(self, counter: int, patience: int) -> None:
        self._counter = counter
        self._patience = patience

    def render(self) -> str:
        return f"Внимание: замечен оверфит. Счётчик: {self._counter}/{self._patience}"

    def render_debug(self) -> str:
        return f"OverfitDetected(counter={self._counter!r}, patience={self._patience!r})"


class ResetTriggered(Event):
    def render(self) -> str:
        return (
            "Критический оверфит! Инициирую сброс до стабильного чекпоинта...\n"
            "Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается."
        )

    def render_debug(self) -> str:
        return "ResetTriggered()"


class ResetSkipped(Event):
    def render(self) -> str:
        return "Критический оверфит, но сохранённого чекпоинта ещё нет — восстанавливать нечего."

    def render_debug(self) -> str:
        return "ResetSkipped()"


class Logger(ABC):
    @abstractmethod
    def log(self, message: str) -> None: ...


class StdoutLogger(Logger):
    def log(self, message: str) -> None:
        print(message)


class Presenter:
    def __init__(self, logger: Logger) -> None:
        self._logger = logger

    def handle(self, events: list[Event]) -> None:
        for event in events:
            self._logger.log(event.render())


class DebugPresenter:
    def __init__(self, logger: Logger) -> None:
        self._logger = logger

    def handle(self, events: list[Event]) -> None:
        for event in events:
            self._logger.log(event.render_debug())


class Tracker:
    def __init__(self, patience: int = 3) -> None:
        self._guard_patience(patience)
        self._patience = patience
        self._overfit_counter = 0
        self._best_loss = float("inf")
        self._checkpoint: str | None = None

    @staticmethod
    def _guard_patience(patience: int) -> None:
        if patience <= 0:
            raise InvalidPatience(f"patience должен быть положительным (patience = {patience})")

    def check_atmosphere(
        self, *, daily_loss: float, current_state: str
    ) -> tuple[str, list[Event]]:
        if self._is_new_best(daily_loss):
            return self._save_checkpoint(daily_loss, current_state)
        return self._register_overfit(current_state)

    def _is_new_best(self, daily_loss: float) -> bool:
        return daily_loss < self._best_loss

    def _save_checkpoint(self, daily_loss: float, current_state: str) -> tuple[str, list[Event]]:
        self._best_loss = daily_loss
        self._overfit_counter = 0
        self._checkpoint = current_state
        return current_state, [CheckpointSaved(daily_loss)]

    def _register_overfit(self, current_state: str) -> tuple[str, list[Event]]:
        self._overfit_counter += 1
        overfit_event = OverfitDetected(self._overfit_counter, self._patience)
        if not self._patience_exhausted():
            return current_state, [overfit_event]
        return self._trigger_reset(current_state, overfit_event)

    def _patience_exhausted(self) -> bool:
        return self._overfit_counter >= self._patience

    def _trigger_reset(self, current_state: str, overfit_event: Event) -> tuple[str, list[Event]]:
        self._overfit_counter = 0
        if self._checkpoint is None:
            return current_state, [overfit_event, ResetSkipped()]
        return self._checkpoint, [overfit_event, ResetTriggered()]


def run() -> None:
    daily_logs = [
        (0.9, "холодный ужин в тишине"),
        (0.4, "вечер с сериалом и чаем"),
        (0.6, "спор из-за посуды"),
        (0.7, "молчанка"),
        (0.8, "снова молчанка"),
    ]
    tracker = Tracker(patience=3)
    presenter = Presenter(StdoutLogger())
    debug_presenter = DebugPresenter(StdoutLogger())

    last_events: list[Event] = []
    for daily_loss, state in daily_logs:
        _, last_events = tracker.check_atmosphere(daily_loss=daily_loss, current_state=state)
        presenter.handle(last_events)

    debug_presenter.handle(last_events)


if __name__ == "__main__":
    try:
        run()
    except InvalidPatience as error:
        print(f"Ошибка: {error}", file=sys.stderr)
