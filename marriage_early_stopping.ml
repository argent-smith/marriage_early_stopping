open Core

(* marriage_early_stopping.ml — версия на Core.

   Архитектура прежняя (SOLID из предыдущей итерации), поверх неё —
   интеграция с Core и монадическая оптимизация в точках, где она
   реально что-то упрощает. Отдельное решение: в файле принципиально
   нет if-then-else — булевы проверки заменены комбинаторами, которые
   превращают условие сразу в значение, а не в ветку:

   1. Tracker.create может завершиться ошибкой (patience <= 0) и
      возвращает 'a t Or_error.t. Вместо if — Result.ok_if_true:
      булева проверка сразу становится (unit, Error.t) Result.t
      (= unit Or_error.t, см. or_error.mli), которая затем через
      (>>|) становится готовым трекером.

   2. Сравнения (daily_loss с best_loss, overfit_counter с patience)
      не проверяются через if, а превращаются в Ordering.t
      (Less/Equal/Greater) через Ordering.of_int — дальше ветвление
      идёт через match. Это буквально пример из ordering.mli самого
      Base: "match Ordering.of_int (compare x y) with Less -> ... |
      Equal -> ... | Greater -> ...".

   3. Tracker.reset и check_atmosphere используют (>>|) из монады
      Option — если значения нет, весь конвейер остаётся None;
      Option.value ~default разворачивает результат в конце. Та же
      логика, что и явный `match ... with None -> ... | Some x ->
      ...`, но выражена цепочкой операторов, а не веткой match.

   Модуль в каждой точке открывается локально (`let open M in ...`),
   а не через `M.(expr)` — граница действия open видна как отдельная
   строка, а не сливается со скобками выражения.

   Остальной код (Event как данные, Logger/Presenter, разделение
   чистого ядра и побочных эффектов) монадической оптимизации не
   требует — совать монаду туда, где хватает обычной композиции
   функций, значило бы усложнять код без пользы.

   Вывод собирается через [%string ...] (ppx_string, часть
   ppx_jane) — интерполирующий ppx: значения подставляются прямо в
   строку (%{expr}, %{expr#Module}), а не идут отдельным списком
   после форматной строки, как у Printf.sprintf. Точную числовую
   формату (3 знака после запятой у loss) ppx_string не заменяет —
   там, где нужен именно printf-формат, он используется точечно,
   как и рекомендует README пакета. *)

(** Чистое ядро: переходы состояния трекера. *)
module Tracker = struct
  type 'a t = {
    patience : int;           (* сколько подряд "душных" дней терпим *)
    overfit_counter : int;
    best_loss : float;
    checkpoint : 'a option;   (* последнее идеальное состояние *)
  }

  (* В Python-оригинале patience=0 или отрицательный тихо ломал бы
     логику (should_reset был бы истинен сразу). Здесь это явная,
     проверяемая на этапе создания ошибка — монада Or_error вместо
     исключения или недосмотра. Result.ok_if_true вместо if: булева
     проверка сама по себе уже значение (unit Or_error.t), а не
     развилка — дальше только (>>|) до готового трекера. *)
  let create ?(patience = 3) () : 'a t Or_error.t =
    let open Or_error in
    (* [%string ...] — интерполирующий ppx (ppx_string, часть
       ppx_jane): значения подставляются прямо в строку, а не идут
       отдельным списком аргументов после форматной строки, как у
       Printf. Error.of_string, а не error_s/[%message]: сообщение
       читает человек, а sexp-квотирование Sexplib экранирует
       кириллицу в восьмеричные escape-последовательности (см.
       Event ниже, где sexp — наоборот то, что нужно, потому что
       это для машины). *)
    Result.ok_if_true (patience > 0)
      ~error:
        (Error.of_string
           [%string "patience должен быть положительным (patience = %{patience#Int})"])
    >>| fun () ->
    { patience; overfit_counter = 0; best_loss = Float.infinity; checkpoint = None }

  (* Сравнение с текущим лучшим лоссом — как Ordering.t, а не bool:
     check_atmosphere ветвится через match, не через if. *)
  let compare_loss t ~loss : Ordering.t = Ordering.of_int (Float.compare loss t.best_loss)

  let save_checkpoint t ~loss ~state =
    { t with best_loss = loss; overfit_counter = 0; checkpoint = Some state }

  let bump_overfit t = { t with overfit_counter = t.overfit_counter + 1 }

  (* Та же идея для терпения: Less — оверфит ещё в пределах patience,
     Equal или Greater — пора сбрасывать до чекпоинта. *)
  let patience_status t : Ordering.t = Ordering.of_int (Int.compare t.overfit_counter t.patience)

  (* Аналог trigger_reset. Инфиксная композиция Option: (>>|) —
     монадический map (если чекпоинта нет, весь конвейер остаётся
     None), а Option.value ~default разворачивает его в конце. Та
     же логика, что и explicit pattern-match, но выражена цепочкой
     операторов, а не веткой match. *)
  let reset t : 'a t * 'a option =
    let open Option in
    t.checkpoint
    >>| (fun state -> ({ t with overfit_counter = 0 }, Some state))
    |> value ~default:(t, None)
end

(** Что произошло на шаге — данные, а не текст.
    [@@deriving sexp_of] — бесплатная структурированная сериализация
    от Core/ppx_jane; пригождается ниже во втором Presenter'е. *)
module Event = struct
  type t =
    | Checkpoint_saved of { loss : float }
    | Overfit_detected of { counter : int; patience : int }
    | Reset_triggered
    | Reset_skipped  (* критический оверфит, но чекпоинта ещё нет *)
  [@@deriving sexp_of]
end

(** Один шаг наблюдения — аналог check_atmosphere из оригинала.
    Ветвление идёт по Ordering.t (Tracker.compare_loss,
    Tracker.patience_status), а не по if. Событие сброса собирается
    инфиксной композицией: (>>|) переносит "restored" в пару (state,
    Reset_triggered), не трогая None; Option.value подставляет
    (current_state, Reset_skipped), если восстанавливать было
    нечего. *)
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

(** Абстракция побочного эффекта вывода — один метод (ISP). *)
module type Logger = sig
  val log : string -> unit
end

module Stdout_logger : Logger = struct
  let log = print_endline
end

(** Текстовый рендер событий — как в оригинале, но собран
    интерполяцией ([%string]) вместо Printf.sprintf с позиционными
    аргументами. Для точности с плавающей точкой (3 знака после
    запятой) сначала форматируем через sprintf "%.3f" — ppx_string
    сам это не умеет (см. README: точное форматирование чисел —
    как раз то, в чём printf удобнее), а затем интерполируем уже
    готовую строку. *)
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

(** Второй способ вывода — структурированный (sexp), без единой
    правки Tracker/Event/Presenter. Ровно то, ради чего Event был
    вынесен в данные, а не сразу в текст (OCP на практике). *)
module Sexp_presenter (L : Logger) = struct
  let handle (events : Event.t list) =
    List.iter events ~f:(fun e -> L.log (Sexp.to_string_hum (Event.sexp_of_t e)))
end

(* --- пример использования --- *)
module App = Presenter (Stdout_logger)
module Debug_app = Sexp_presenter (Stdout_logger)

let run () : unit Or_error.t =
  (* Инфиксная монадическая композиция: (>>|) = Or_error.map, то
     есть "t >>= fun x -> return (f x)" одним оператором. Берём
     >>|, а не >>=, потому что тело справа само уже не производит
     Or_error — оно чистый unit; будь там ещё один шаг, способный
     упасть (скажем, второй Tracker.create), понадобился бы >>=,
     чтобы не заворачивать Or_error в Or_error. *)
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
