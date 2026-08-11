require_relative "../marriage_early_stopping_fp"

RSpec.describe MarriageEarlyStopping::Fp do
  let(:factory) { MarriageEarlyStopping::Fp::TrackerFactory.new }
  let(:check_atmosphere) { MarriageEarlyStopping::Fp::CheckAtmosphere.new }

  describe MarriageEarlyStopping::Fp::TrackerFactory do
    it "rejects patience <= 0" do
      result = factory.call(patience: 0)

      expect(result).to eq(Dry::Monads::Failure("patience должен быть положительным (patience = 0)"))
    end

    it "accepts a positive patience" do
      result = factory.call(patience: 3)

      expect(result).to be_success
      result.fmap { |tracker| expect(tracker.patience).to eq(3) }
    end

    it "defaults overfit_counter/best_loss/checkpoint on the underlying Tracker struct" do
      tracker = factory.call(patience: 3).value!

      expect(tracker.overfit_counter).to eq(0)
      expect(tracker.best_loss).to eq(Float::INFINITY)
      expect(tracker.checkpoint).to eq(Dry::Monads::None())
    end
  end

  describe MarriageEarlyStopping::Fp::CheckAtmosphere do
    it "the first day is always a checkpoint, and does not mutate the input tracker" do
      tracker = factory.call(patience: 3).value!

      new_tracker, state, events = check_atmosphere.call(tracker, daily_loss: 0.9, current_state: "day1")

      expect(state).to eq("day1")
      expect(events).to eq([MarriageEarlyStopping::Fp::CheckpointSaved.new(loss: 0.9)])
      expect(new_tracker.best_loss).to eq(0.9)
      expect(tracker.best_loss).to eq(Float::INFINITY)
    end

    it "increments the overfit counter without resetting" do
      tracker = factory.call(patience: 3).value!
      tracker, = check_atmosphere.call(tracker, daily_loss: 0.4, current_state: "best")

      _, _, events = check_atmosphere.call(tracker, daily_loss: 0.6, current_state: "worse")

      expect(events).to eq([MarriageEarlyStopping::Fp::OverfitDetected.new(counter: 1, patience: 3)])
    end

    it "triggers a reset after patience is exhausted and restores the checkpoint" do
      tracker = factory.call(patience: 2).value!
      tracker, = check_atmosphere.call(tracker, daily_loss: 0.4, current_state: "best")
      tracker, = check_atmosphere.call(tracker, daily_loss: 0.6, current_state: "worse-1")

      tracker, state, events = check_atmosphere.call(tracker, daily_loss: 0.7, current_state: "worse-2")

      expect(state).to eq("best")
      expect(events).to eq([
                             MarriageEarlyStopping::Fp::OverfitDetected.new(counter: 2, patience: 2),
                             MarriageEarlyStopping::Fp::ResetTriggered.new
                           ])
      expect(tracker.overfit_counter).to eq(0)
    end
  end

  describe MarriageEarlyStopping::Fp::Simulation do
    it "prints the demo scenario" do
      result = nil
      expect { result = MarriageEarlyStopping::Fp::Simulation.new.call }.to output(
        "Чекпоинт сохранён: атмосфера идеальная (loss=0.900). Веса зафиксированы.\n" \
        "Чекпоинт сохранён: атмосфера идеальная (loss=0.400). Веса зафиксированы.\n" \
        "Внимание: замечен оверфит. Счётчик: 1/3\n" \
        "Внимание: замечен оверфит. Счётчик: 2/3\n" \
        "Внимание: замечен оверфит. Счётчик: 3/3\n" \
        "Критический оверфит! Инициирую сброс до стабильного чекпоинта...\n" \
        "Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается.\n" \
        "#<MarriageEarlyStopping::Fp::OverfitDetected counter=3 patience=3>\n" \
        "#<MarriageEarlyStopping::Fp::ResetTriggered>\n"
      ).to_stdout
      expect(result).to be_success
    end

    it "composes injected collaborators instead of hardcoding them" do
      spy_logger = Class.new { def log(message) = (@logged ||= []) << message }.new
      simulation = MarriageEarlyStopping::Fp::Simulation.new(
        presenter: MarriageEarlyStopping::Fp::Presenter.new(spy_logger),
        debug_presenter: MarriageEarlyStopping::Fp::DebugPresenter.new(spy_logger)
      )

      expect { simulation.call }.not_to output.to_stdout
    end
  end
end
