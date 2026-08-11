require_relative "../marriage_early_stopping_oop"

RSpec.describe MarriageEarlyStopping::Oop do
  describe MarriageEarlyStopping::Oop::Tracker do
    it "raises InvalidPatienceError for patience <= 0" do
      expect { described_class.new(patience: 0) }
        .to raise_error(MarriageEarlyStopping::Oop::InvalidPatienceError, /patience = 0/)
    end

    it "raises for negative patience too" do
      expect { described_class.new(patience: -1) }
        .to raise_error(MarriageEarlyStopping::Oop::InvalidPatienceError, /patience = -1/)
    end

    it "the first day is always a checkpoint" do
      tracker = described_class.new(patience: 3)

      state, events = tracker.check_atmosphere(daily_loss: 0.9, current_state: "day1")

      expect(state).to eq("day1")
      expect(events).to contain_exactly(an_instance_of(MarriageEarlyStopping::Oop::CheckpointSaved))
    end

    it "increments the overfit counter without resetting" do
      tracker = described_class.new(patience: 3)
      tracker.check_atmosphere(daily_loss: 0.4, current_state: "best")

      _, events = tracker.check_atmosphere(daily_loss: 0.6, current_state: "worse")

      expect(events).to contain_exactly(
        MarriageEarlyStopping::Oop::OverfitDetected.new(counter: 1, patience: 3)
      )
    end

    it "triggers a reset after patience is exhausted and restores the checkpoint" do
      tracker = described_class.new(patience: 2)
      tracker.check_atmosphere(daily_loss: 0.4, current_state: "best")
      tracker.check_atmosphere(daily_loss: 0.6, current_state: "worse-1")

      state, events = tracker.check_atmosphere(daily_loss: 0.7, current_state: "worse-2")

      expect(state).to eq("best")
      expect(events).to contain_exactly(
        MarriageEarlyStopping::Oop::OverfitDetected.new(counter: 2, patience: 2),
        MarriageEarlyStopping::Oop::ResetTriggered.new
      )
      expect(tracker.overfit_counter).to eq(0)
    end
  end

  it "prints the demo scenario" do
    expect { described_class.run }.to output(
      "Чекпоинт сохранён: атмосфера идеальная (loss=0.900). Веса зафиксированы.\n" \
      "Чекпоинт сохранён: атмосфера идеальная (loss=0.400). Веса зафиксированы.\n" \
      "Внимание: замечен оверфит. Счётчик: 1/3\n" \
      "Внимание: замечен оверфит. Счётчик: 2/3\n" \
      "Внимание: замечен оверфит. Счётчик: 3/3\n" \
      "Критический оверфит! Инициирую сброс до стабильного чекпоинта...\n" \
      "Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается.\n" \
      "#<data MarriageEarlyStopping::Oop::OverfitDetected counter=3, patience=3>\n" \
      "#<data MarriageEarlyStopping::Oop::ResetTriggered>\n"
    ).to_stdout
  end
end
