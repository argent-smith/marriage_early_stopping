require "dry/monads"
require "dry/struct"
require "dry/validation"

Dry::Validation.load_extensions(:monads)

module MarriageEarlyStopping
  module Fp
    module Types
      include Dry.Types()
    end

    class CheckpointSaved < Dry::Struct
      attribute :loss, Types::Strict::Float
    end

    class OverfitDetected < Dry::Struct
      attribute :counter, Types::Strict::Integer
      attribute :patience, Types::Strict::Integer
    end

    class ResetTriggered < Dry::Struct; end

    class ResetSkipped < Dry::Struct; end

    class Tracker < Dry::Struct
      attribute :patience, Types::Strict::Integer
      attribute :overfit_counter, Types::Strict::Integer.default(0)
      attribute :best_loss, Types::Strict::Float.default(Float::INFINITY)
      attribute(:checkpoint, Types.Instance(Dry::Monads::Maybe).default { Dry::Monads::None() })
    end

    class PatienceContract < Dry::Validation::Contract
      params { required(:patience).filled(:integer, gt?: 0) }
    end

    class TrackerFactory
      extend Dry::Initializer
      include Dry::Monads[:result]

      option :contract, default: -> { PatienceContract.new }

      def call(patience: 3)
        contract.call(patience:).to_monad
                .fmap { |validated| Tracker.new(patience: validated[:patience]) }
                .or { Failure("patience должен быть положительным (patience = #{patience})") }
      end
    end

    class CheckAtmosphere
      include Dry::Monads[:maybe]

      def call(tracker, daily_loss:, current_state:)
        checkpoint_step(tracker, daily_loss, current_state)
          .or { overfit_step(tracker, current_state) }
          .value!
      end

      private

      def checkpoint_step(tracker, daily_loss, current_state)
        return None() unless daily_loss < tracker.best_loss

        tracker = save_checkpoint(tracker, loss: daily_loss, state: current_state)
        Some([tracker, current_state, [CheckpointSaved.new(loss: daily_loss)]])
      end

      def overfit_step(tracker, current_state)
        tracker = bump_overfit(tracker)
        overfit_event = OverfitDetected.new(counter: tracker.overfit_counter, patience: tracker.patience)
        return Some([tracker, current_state, [overfit_event]]) if tracker.overfit_counter < tracker.patience

        tracker, restored = reset(tracker)
        current_state, reset_event =
          restored.fmap { |state| [state, ResetTriggered.new] }.value_or([current_state, ResetSkipped.new])
        Some([tracker, current_state, [overfit_event, reset_event]])
      end

      def save_checkpoint(tracker, loss:, state:)
        tracker.new(best_loss: loss, overfit_counter: 0, checkpoint: Some(state))
      end

      def bump_overfit(tracker) = tracker.new(overfit_counter: tracker.overfit_counter + 1)

      def reset(tracker)
        tracker.checkpoint.fmap { |state| [tracker.new(overfit_counter: 0), Some(state)] }.value_or([tracker, None()])
      end
    end

    class StdoutLogger
      def log(message) = puts message
    end

    class Presenter
      extend Dry::Initializer

      param :logger

      def handle(events) = events.each { |event| logger.log(render(event)) }

      private

      def render(event)
        case event
        in CheckpointSaved(loss:)
          format("Чекпоинт сохранён: атмосфера идеальная (loss=%.3f). Веса зафиксированы.", loss)
        in OverfitDetected(counter:, patience:)
          "Внимание: замечен оверфит. Счётчик: #{counter}/#{patience}"
        in ResetTriggered
          "Критический оверфит! Инициирую сброс до стабильного чекпоинта...\n" \
          "Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается."
        in ResetSkipped
          "Критический оверфит, но сохранённого чекпоинта ещё нет — восстанавливать нечего."
        end
      end
    end

    class DebugPresenter
      extend Dry::Initializer

      param :logger

      def handle(events) = events.each { |event| logger.log(event.inspect) }
    end

    class Simulation
      extend Dry::Initializer

      DAILY_LOGS = [
        [0.9, "холодный ужин в тишине"],
        [0.4, "вечер с сериалом и чаем"],
        [0.6, "спор из-за посуды"],
        [0.7, "молчанка"],
        [0.8, "снова молчанка"]
      ].freeze

      option :tracker_factory, default: -> { TrackerFactory.new }
      option :check_atmosphere, default: -> { CheckAtmosphere.new }
      option :presenter, default: -> { Presenter.new(StdoutLogger.new) }
      option :debug_presenter, default: -> { DebugPresenter.new(StdoutLogger.new) }

      def call = tracker_factory.call(patience: 3).fmap(method(:run))

      private

      def run(tracker)
        *, events = DAILY_LOGS.reduce([tracker, "", []]) do |(current_tracker, *), (daily_loss, state)|
          check_atmosphere.call(current_tracker, daily_loss:, current_state: state)
                          .tap { |_tracker, _current_state, events| presenter.handle(events) }
        end
        debug_presenter.handle(events)
      end
    end
  end
end

MarriageEarlyStopping::Fp::Simulation.new.call.or { |error| warn "Ошибка: #{error}" } if __FILE__ == $PROGRAM_NAME
