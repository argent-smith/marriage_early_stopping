class MarriageEarlyStopping:
    def __init__(self, patience=3):
        self.patience = patience  # Сколько дней подряд можно терпеть душность
        self.overfit_counter = 0
        self.best_relationship_loss = float('inf')
        self.checkpoint_memories = None

    def check_atmosphere(self, daily_loss, current_state):
        if daily_loss < self.best_relationship_loss:
            # Нашли идеальный баланс, сохраняем этот чекпоинт в памяти
            self.best_relationship_loss = daily_loss
            self.overfit_counter = 0
            self.checkpoint_memories = current_state.copy()
            print("Чекпоинт сохранен: атмосфера идеальная. Веса зафиксированы.")
        else:
            # Лосс растет, агент переобучился на обидах
            self.overfit_counter += 1
            print(f"Внимание: замечен оверфит. Счетчик: {self.overfit_counter}/{self.patience}")

            if self.overfit_counter >= self.patience:
                self.trigger_reset(current_state)

    def trigger_reset(self, current_state):
        print("🚨 Критический оверфит! Инициирую сброс до стабильного чекпоинта...")
        # Удаляем накопленный баг-лог, везем агента на свидание/кофе
        current_state.load(self.checkpoint_memories)
        self.overfit_counter = 0
        print("🔄 Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается.")


# === Всё выше — транскрипция скриншота 1:1, без изменений. ===
# === Всё ниже добавлено отдельно, чтобы файл можно было реально запустить. ===

# check_atmosphere()/trigger_reset() вызывают current_state.copy() и
# current_state.load(...), но какой тип у current_state — в оригинале
# (это псевдокод со скриншота) не указано. RelationshipState — не из
# оригинала, минимальная заглушка ровно под эти два вызова.
class RelationshipState:
    def __init__(self, description):
        self.description = description

    def copy(self):
        return RelationshipState(self.description)

    def load(self, other):
        self.description = other.description

    def __str__(self):
        return self.description


if __name__ == "__main__":
    # Тот же сценарий (5 дней, patience=3), что и в остальных портах в
    # этом репозитории — чтобы вывод можно было сравнивать между всеми
    # вариантами.
    tracker = MarriageEarlyStopping(patience=3)
    daily_logs = [
        (0.9, "холодный ужин в тишине"),
        (0.4, "вечер с сериалом и чаем"),
        (0.6, "спор из-за посуды"),
        (0.7, "молчанка"),
        (0.8, "снова молчанка"),
    ]
    for daily_loss, description in daily_logs:
        # В оригинале check_atmosphere ничего не возвращает и нигде не
        # сохраняет current_state между вызовами — состояние, которое
        # trigger_reset восстанавливает через .load(...), здесь же и
        # теряется. Это не баг обвязки: оригинал действительно так
        # написан, и это намеренно не исправляется — обвязка лишь
        # запускает код как есть.
        tracker.check_atmosphere(daily_loss, RelationshipState(description))
