from __future__ import annotations

import sys
from dataclasses import dataclass, replace
from functools import reduce
from typing import Protocol, Self

from returns.maybe import Maybe, Nothing, Some
from returns.result import Failure, Result, Success


@dataclass(frozen=True)
class CheckpointSaved:
    loss: float


@dataclass(frozen=True)
class OverfitDetected:
    counter: int
    patience: int


@dataclass(frozen=True)
class ResetTriggered:
    pass


@dataclass(frozen=True)
class ResetSkipped:
    pass


Event = CheckpointSaved | OverfitDetected | ResetTriggered | ResetSkipped


@dataclass(frozen=True)
class Tracker:
    patience: int
    overfit_counter: int = 0
    best_loss: float = float("inf")
    checkpoint: Maybe[str] = Nothing

    @staticmethod
    def create(patience: int = 3) -> Result[Tracker, str]:
        return (
            Success(Tracker(patience=patience))
            if patience > 0
            else Failure(f"patience должен быть положительным (patience = {patience})")
        )

    def save_checkpoint(self, *, loss: float, state: str) -> Self:
        return replace(self, best_loss=loss, overfit_counter=0, checkpoint=Some(state))

    def bump_overfit(self) -> Self:
        return replace(self, overfit_counter=self.overfit_counter + 1)

    def reset(self) -> tuple[Self, Maybe[str]]:
        return self.checkpoint.map(
            lambda state: (replace(self, overfit_counter=0), Some(state))
        ).value_or((self, Nothing))


def check_atmosphere(
    tracker: Tracker, *, daily_loss: float, current_state: str
) -> tuple[Tracker, str, list[Event]]:
    if daily_loss < tracker.best_loss:
        tracker = tracker.save_checkpoint(loss=daily_loss, state=current_state)
        return tracker, current_state, [CheckpointSaved(daily_loss)]

    tracker = tracker.bump_overfit()
    overfit_event = OverfitDetected(tracker.overfit_counter, tracker.patience)
    if tracker.overfit_counter < tracker.patience:
        return tracker, current_state, [overfit_event]

    tracker, restored = tracker.reset()
    match restored:
        case Some(state):
            return tracker, state, [overfit_event, ResetTriggered()]
        case _:
            return tracker, current_state, [overfit_event, ResetSkipped()]


class Logger(Protocol):
    def log(self, message: str) -> None: ...


class StdoutLogger:
    def log(self, message: str) -> None:
        print(message)


def render(event: Event) -> str:
    match event:
        case CheckpointSaved(loss=loss):
            return f"Чекпоинт сохранён: атмосфера идеальная (loss={loss:.3f}). Веса зафиксированы."
        case OverfitDetected(counter=counter, patience=patience):
            return f"Внимание: замечен оверфит. Счётчик: {counter}/{patience}"
        case ResetTriggered():
            return (
                "Критический оверфит! Инициирую сброс до стабильного чекпоинта...\n"
                "Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается."
            )
        case ResetSkipped():
            return (
                "Критический оверфит, но сохранённого чекпоинта ещё нет — восстанавливать нечего."
            )


class Presenter:
    def __init__(self, logger: Logger) -> None:
        self._logger = logger

    def handle(self, events: list[Event]) -> None:
        for event in events:
            self._logger.log(render(event))


class DebugPresenter:
    def __init__(self, logger: Logger) -> None:
        self._logger = logger

    def handle(self, events: list[Event]) -> None:
        for event in events:
            self._logger.log(repr(event))


Step = tuple[Tracker, str, list[Event]]


def run() -> Result[None, str]:
    daily_logs = [
        (0.9, "холодный ужин в тишине"),
        (0.4, "вечер с сериалом и чаем"),
        (0.6, "спор из-за посуды"),
        (0.7, "молчанка"),
        (0.8, "снова молчанка"),
    ]
    presenter = Presenter(StdoutLogger())
    debug_presenter = DebugPresenter(StdoutLogger())

    def simulate(tracker: Tracker) -> None:
        def step(acc: Step, entry: tuple[float, str]) -> Step:
            tracker, _, _ = acc
            daily_loss, log_state = entry
            tracker, state, events = check_atmosphere(
                tracker, daily_loss=daily_loss, current_state=log_state
            )
            presenter.handle(events)
            return tracker, state, events

        _, _, last_events = reduce(step, daily_logs, (tracker, "", []))
        debug_presenter.handle(last_events)

    return Tracker.create(patience=3).map(simulate)


def main() -> None:
    match run():
        case Failure(error):
            print(f"Ошибка: {error}", file=sys.stderr)
        case Success(_):
            pass


if __name__ == "__main__":
    main()
