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
