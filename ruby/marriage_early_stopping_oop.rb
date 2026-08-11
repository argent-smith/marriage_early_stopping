module MarriageEarlyStopping
  module Oop
    class InvalidPatienceError < ArgumentError
    end

    CheckpointSaved = Data.define(:loss) do
      def render = format("Чекпоинт сохранён: атмосфера идеальная (loss=%.3f). Веса зафиксированы.", loss)
    end

    OverfitDetected = Data.define(:counter, :patience) do
      def render = "Внимание: замечен оверфит. Счётчик: #{counter}/#{patience}"
    end

    ResetTriggered = Data.define do
      def render
        "Критический оверфит! Инициирую сброс до стабильного чекпоинта...\n" \
          "Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается."
      end
    end

    ResetSkipped = Data.define do
      def render = "Критический оверфит, но сохранённого чекпоинта ещё нет — восстанавливать нечего."
    end

    class StdoutLogger
      def log(message) = puts message
    end

    class Presenter
      def initialize(logger) = @logger = logger

      def handle(events) = events.each { |event| @logger.log(event.render) }
    end

    class DebugPresenter
      def initialize(logger) = @logger = logger

      def handle(events) = events.each { |event| @logger.log(event.inspect) }
    end

    class Tracker
      def initialize(patience: 3)
        unless patience.positive?
          raise InvalidPatienceError, "patience должен быть положительным (patience = #{patience})"
        end

        @patience = patience
        @overfit_counter = 0
        @best_loss = Float::INFINITY
        @checkpoint = nil
      end

      def check_atmosphere(daily_loss:, current_state:)
        return save_checkpoint(daily_loss, current_state) if new_best?(daily_loss)

        register_overfit(current_state)
      end

      attr_reader :overfit_counter, :best_loss

      private

      def new_best?(daily_loss) = daily_loss < @best_loss

      def save_checkpoint(daily_loss, current_state)
        @best_loss = daily_loss
        @overfit_counter = 0
        @checkpoint = current_state
        [current_state, [CheckpointSaved.new(loss: daily_loss)]]
      end

      def register_overfit(current_state)
        @overfit_counter += 1
        overfit_event = OverfitDetected.new(counter: @overfit_counter, patience: @patience)
        return [current_state, [overfit_event]] unless patience_exhausted?

        trigger_reset(current_state, overfit_event)
      end

      def patience_exhausted? = @overfit_counter >= @patience

      def trigger_reset(current_state, overfit_event)
        @overfit_counter = 0
        return [current_state, [overfit_event, ResetSkipped.new]] if @checkpoint.nil?

        [@checkpoint, [overfit_event, ResetTriggered.new]]
      end
    end

    def self.run
      daily_logs = [
        [0.9, "холодный ужин в тишине"],
        [0.4, "вечер с сериалом и чаем"],
        [0.6, "спор из-за посуды"],
        [0.7, "молчанка"],
        [0.8, "снова молчанка"]
      ]
      tracker = Tracker.new(patience: 3)
      presenter = Presenter.new(StdoutLogger.new)
      debug_presenter = DebugPresenter.new(StdoutLogger.new)

      events = []
      daily_logs.each do |daily_loss, state|
        _, events = tracker.check_atmosphere(daily_loss:, current_state: state)
        presenter.handle(events)
      end
      debug_presenter.handle(events)
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  begin
    MarriageEarlyStopping::Oop.run
  rescue MarriageEarlyStopping::Oop::InvalidPatienceError => e
    warn "Ошибка: #{e.message}"
  end
end
