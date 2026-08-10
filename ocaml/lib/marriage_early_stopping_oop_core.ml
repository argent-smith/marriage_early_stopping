open Core

module Event = struct
  type t =
    | Checkpoint_saved of { loss : float }
    | Overfit_detected of { counter : int; patience : int }
    | Reset_triggered
    | Reset_skipped
  [@@deriving sexp_of, equal]
end

module Tracker = struct
  class ['a] t ~patience () =
    object
      val patience = patience
      val mutable overfit_counter = 0
      val mutable best_loss = Float.infinity
      val mutable checkpoint : 'a option = None

      method check_atmosphere ~daily_loss ~(current_state : 'a) : 'a * Event.t list =
        let open Ordering in
        match Ordering.of_int (Float.compare daily_loss best_loss) with
        | Less ->
          best_loss <- daily_loss;
          overfit_counter <- 0;
          checkpoint <- Some current_state;
          (current_state, [ Event.Checkpoint_saved { loss = daily_loss } ])
        | Equal | Greater ->
          overfit_counter <- overfit_counter + 1;
          let overfit_event =
            Event.Overfit_detected { counter = overfit_counter; patience }
          in
          (match Ordering.of_int (Int.compare overfit_counter patience) with
           | Less -> (current_state, [ overfit_event ])
           | Equal | Greater ->
             let open Option in
             let restored_state, reset_event =
               checkpoint
               >>| (fun state -> (state, Event.Reset_triggered))
               |> value ~default:(current_state, Event.Reset_skipped)
             in
             iter checkpoint ~f:(fun _ -> overfit_counter <- 0);
             (restored_state, [ overfit_event; reset_event ]))

      method overfit_counter = overfit_counter
      method best_loss = best_loss
    end

  let create ?(patience = 3) () : 'a t Or_error.t =
    let open Or_error in
    Result.ok_if_true (patience > 0)
      ~error:
        (Error.of_string
           [%string "patience должен быть положительным (patience = %{patience#Int})"])
    >>| fun () -> new t ~patience ()
end

module type Logger = sig
  val log : string -> unit
end

module Stdout_logger : Logger = struct
  let log = print_endline
end

module Presenter (L : Logger) = struct
  let render : Event.t -> string = function
    | Checkpoint_saved { loss } ->
      let loss = sprintf "%.3f" loss in
      [%string "Чекпоинт сохранён: атмосфера идеальная (loss=%{loss}). Веса зафиксированы."]
    | Overfit_detected { counter; patience } ->
      [%string "Внимание: замечен оверфит. Счётчик: %{counter#Int}/%{patience#Int}"]
    | Reset_triggered ->
      "Критический оверфит! Инициирую сброс до стабильного чекпоинта...\n\
       Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается."
    | Reset_skipped ->
      "Критический оверфит, но сохранённого чекпоинта ещё нет — восстанавливать нечего."

  let handle (events : Event.t list) = List.iter events ~f:(fun e -> L.log (render e))
end

module Sexp_presenter (L : Logger) = struct
  let handle (events : Event.t list) =
    List.iter events ~f:(fun e -> L.log (Sexp.to_string_hum (Event.sexp_of_t e)))
end

module App = Presenter (Stdout_logger)
module Debug_app = Sexp_presenter (Stdout_logger)

let run () : unit Or_error.t =
  let open Or_error in
  Tracker.create ~patience:3 ()
  >>| fun tracker ->
  let daily_logs =
    [ (0.9, "холодный ужин в тишине")
    ; (0.4, "вечер с сериалом и чаем")
    ; (0.6, "спор из-за посуды")
    ; (0.7, "молчанка")
    ; (0.8, "снова молчанка")
    ]
  in
  let _, last_events =
    List.fold daily_logs ~init:("", [])
      ~f:(fun (_current, _events) (loss, state) ->
        let current', events = tracker#check_atmosphere ~daily_loss:loss ~current_state:state in
        App.handle events;
        (current', events))
  in
  Debug_app.handle last_events
