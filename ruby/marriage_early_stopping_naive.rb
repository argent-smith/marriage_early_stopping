module MarriageEarlyStopping
  module Naive
    class RelationshipState
      attr_reader :description

      def initialize(description) = @description = description

      def copy = RelationshipState.new(description)

      def load(other) = @description = other.description

      def to_s = description
    end

    class Tracker
      attr_reader :overfit_counter, :best_relationship_loss

      def initialize(patience = 3)
        @patience = patience
        @overfit_counter = 0
        @best_relationship_loss = Float::INFINITY
        @checkpoint_memories = nil
      end

      def check_atmosphere(daily_loss, current_state)
        if daily_loss < @best_relationship_loss
          @best_relationship_loss = daily_loss
          @overfit_counter = 0
          @checkpoint_memories = current_state.copy
          puts "Чекпоинт сохранён: атмосфера идеальная. Веса зафиксированы."
        else
          @overfit_counter += 1
          puts "Внимание: замечен оверфит. Счётчик: #{@overfit_counter}/#{@patience}"
          trigger_reset(current_state) if @overfit_counter >= @patience
        end
      end

      def trigger_reset(current_state)
        puts "🚨 Критический оверфит! Инициирую сброс до стабильного чекпоинта..."
        current_state.load(@checkpoint_memories)
        @overfit_counter = 0
        puts "🔄 Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается."
      end
    end

    def self.run
      tracker = Tracker.new(3)
      daily_logs = [
        [0.9, "холодный ужин в тишине"],
        [0.4, "вечер с сериалом и чаем"],
        [0.6, "спор из-за посуды"],
        [0.7, "молчанка"],
        [0.8, "снова молчанка"]
      ]
      daily_logs.each do |daily_loss, state|
        tracker.check_atmosphere(daily_loss, RelationshipState.new(state))
      end
    end
  end
end

MarriageEarlyStopping::Naive.run if __FILE__ == $PROGRAM_NAME
