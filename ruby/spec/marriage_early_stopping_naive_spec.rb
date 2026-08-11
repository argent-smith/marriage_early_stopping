require_relative "../marriage_early_stopping_naive"

RSpec.describe MarriageEarlyStopping::Naive do
  describe MarriageEarlyStopping::Naive::RelationshipState do
    it "copy is independent from the original" do
      original = described_class.new("вечер с сериалом и чаем")
      copy = original.copy
      copy.load(described_class.new("другое состояние"))

      expect(original.description).to eq("вечер с сериалом и чаем")
      expect(copy.description).to eq("другое состояние")
    end

    it "load mutates in place" do
      state = described_class.new("начало")
      state.load(described_class.new("конец"))

      expect(state.description).to eq("конец")
    end
  end

  describe MarriageEarlyStopping::Naive::Tracker do
    it "accepts any patience without validation" do
      expect { described_class.new(0) }.not_to raise_error
    end

    it "reproduces the original bug at patience=0: resets on the very first overfit day" do
      tracker = described_class.new(0)
      best = MarriageEarlyStopping::Naive::RelationshipState.new("best")
      worse = MarriageEarlyStopping::Naive::RelationshipState.new("worse")

      silence_stdout { tracker.check_atmosphere(0.4, best) }
      silence_stdout { tracker.check_atmosphere(0.6, worse) }

      expect(tracker.overfit_counter).to eq(0)
      expect(worse.description).to eq("best")
    end

    it "behaves normally with a sane patience" do
      tracker = described_class.new(3)
      state = MarriageEarlyStopping::Naive::RelationshipState.new("best")

      silence_stdout { tracker.check_atmosphere(0.4, state) }

      expect(tracker.best_relationship_loss).to eq(0.4)
      expect(tracker.overfit_counter).to eq(0)
    end
  end

  it "prints the demo scenario with the original's exact wording (no loss, with emoji)" do
    expect { described_class.run }.to output(
      "Чекпоинт сохранён: атмосфера идеальная. Веса зафиксированы.\n" \
      "Чекпоинт сохранён: атмосфера идеальная. Веса зафиксированы.\n" \
      "Внимание: замечен оверфит. Счётчик: 1/3\n" \
      "Внимание: замечен оверфит. Счётчик: 2/3\n" \
      "Внимание: замечен оверфит. Счётчик: 3/3\n" \
      "🚨 Критический оверфит! Инициирую сброс до стабильного чекпоинта...\n" \
      "🔄 Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается.\n"
    ).to_stdout
  end
end
