open Core

class marriage_early_stopping ?(patience = 3) () =
  object (self)
    val mutable overfit_counter = 0
    val mutable best_relationship_loss = Float.infinity
    val mutable checkpoint_memories : string option = None

    method overfit_counter = overfit_counter
    method best_relationship_loss = best_relationship_loss

    method check_atmosphere ~daily_loss (current_state : string ref) =
      if Float.(daily_loss < best_relationship_loss) then begin
        best_relationship_loss <- daily_loss;
        overfit_counter <- 0;
        checkpoint_memories <- Some !current_state;
        print_endline "Чекпоинт сохранён: атмосфера идеальная. Веса зафиксированы."
      end
      else begin
        overfit_counter <- overfit_counter + 1;
        printf "Внимание: замечен оверфит. Счётчик: %d/%d\n" overfit_counter patience;
        if overfit_counter >= patience then self#trigger_reset current_state
      end

    method trigger_reset (current_state : string ref) =
      print_endline "🚨 Критический оверфит! Инициирую сброс до стабильного чекпоинта...";
      current_state := Option.value_exn checkpoint_memories;
      overfit_counter <- 0;
      print_endline
        "🔄 Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается."
  end

let run () =
  let tracker = new marriage_early_stopping ~patience:3 () in
  let daily_logs =
    [ (0.9, "холодный ужин в тишине")
    ; (0.4, "вечер с сериалом и чаем")
    ; (0.6, "спор из-за посуды")
    ; (0.7, "молчанка")
    ; (0.8, "снова молчанка")
    ]
  in
  List.iter daily_logs ~f:(fun (daily_loss, state) ->
    let current_state = ref state in
    tracker#check_atmosphere ~daily_loss current_state)
