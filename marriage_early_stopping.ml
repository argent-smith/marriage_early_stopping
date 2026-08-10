open Core

module Tracker = struct
  type 'a t = {
    patience : int;
    overfit_counter : int;
    best_loss : float;
    checkpoint : 'a option;
  }

  let create ?(patience = 3) () : 'a t Or_error.t =
    let open Or_error in
    Result.ok_if_true (patience > 0)
      ~error:
        (Error.of_string
           [%string "patience должен быть положительным (patience = %{patience#Int})"])
    >>| fun () ->
    { patience; overfit_counter = 0; best_loss = Float.infinity; checkpoint = None }

  let compare_loss t ~loss : Ordering.t = Ordering.of_int (Float.compare loss t.best_loss)

  let save_checkpoint t ~loss ~state =
    { t with best_loss = loss; overfit_counter = 0; checkpoint = Some state }

  let bump_overfit t = { t with overfit_counter = t.overfit_counter + 1 }

  let patience_status t : Ordering.t =
    Ordering.of_int (Int.compare t.overfit_counter t.patience)

  let reset t : 'a t * 'a option =
    let open Option in
    t.checkpoint
    >>| (fun state -> ({ t with overfit_counter = 0 }, Some state))
    |> value ~default:(t, None)
end

module Event = struct
  type t =
    | Checkpoint_saved of { loss : float }
    | Overfit_detected of { counter : int; patience : int }
    | Reset_triggered
    | Reset_skipped
  [@@deriving sexp_of]
end

let check_atmosphere (type a) (t : a Tracker.t) ~(daily_loss : float)
    ~(current_state : a) : a Tracker.t * a * Event.t list =
  let open Ordering in
  match Tracker.compare_loss t ~loss:daily_loss with
  | Less ->
    let t' = Tracker.save_checkpoint t ~loss:daily_loss ~state:current_state in
    (t', current_state, [ Event.Checkpoint_saved { loss = daily_loss } ])
  | Equal | Greater ->
    let t' = Tracker.bump_overfit t in
    let overfit_event =
      Event.Overfit_detected { counter = t'.overfit_counter; patience = t'.patience }
    in
    (match Tracker.patience_status t' with
     | Less -> (t', current_state, [ overfit_event ])
     | Equal | Greater ->
       let t'', restored = Tracker.reset t' in
       let current_state', reset_event =
         let open Option in
         restored
         >>| (fun state -> (state, Event.Reset_triggered))
         |> value ~default:(current_state, Event.Reset_skipped)
       in
       (t'', current_state', [ overfit_event; reset_event ]))

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
  let (_, _, last_events) =
    List.fold daily_logs ~init:(tracker, "", [])
      ~f:(fun (tracker, _current, _events) (loss, state) ->
        let tracker', current, events =
          check_atmosphere tracker ~daily_loss:loss ~current_state:state
        in
        App.handle events;
        (tracker', current, events))
  in
  Debug_app.handle last_events

let () =
  match run () with
  | Ok () -> ()
  | Error err -> prerr_endline [%string "Ошибка: %{Error.to_string_hum err}"]
