open Core

(* --- functional (marriage_early_stopping_core) --- *)

let functional_event_testable =
  Alcotest.testable
    (fun fmt e ->
      Fmt.string fmt (Sexp.to_string_hum (Marriage_early_stopping_core.Event.sexp_of_t e)))
    Marriage_early_stopping_core.Event.equal

let test_create_rejects_non_positive_patience () =
  match Marriage_early_stopping_core.Tracker.create ~patience:0 () with
  | Error err ->
    Alcotest.(check string)
      "error message" "patience должен быть положительным (patience = 0)"
      (Error.to_string_hum err)
  | Ok _ -> Alcotest.fail "expected Error for patience = 0"

let test_create_accepts_positive_patience () =
  match Marriage_early_stopping_core.Tracker.create ~patience:3 () with
  | Ok _ -> ()
  | Error err -> Alcotest.failf "unexpected error: %s" (Error.to_string_hum err)

let test_first_day_is_always_a_checkpoint () =
  let tracker = Marriage_early_stopping_core.Tracker.create ~patience:3 () |> Or_error.ok_exn in
  let _, state, events =
    Marriage_early_stopping_core.check_atmosphere tracker ~daily_loss:0.9 ~current_state:"day1"
  in
  Alcotest.(check string) "state unchanged" "day1" state;
  Alcotest.(check (list functional_event_testable))
    "events"
    [ Marriage_early_stopping_core.Event.Checkpoint_saved { loss = 0.9 } ]
    events

let test_overfit_counter_increments_without_reset () =
  let tracker = Marriage_early_stopping_core.Tracker.create ~patience:3 () |> Or_error.ok_exn in
  let tracker, _, _ =
    Marriage_early_stopping_core.check_atmosphere tracker ~daily_loss:0.4 ~current_state:"best"
  in
  let _, _, events =
    Marriage_early_stopping_core.check_atmosphere tracker ~daily_loss:0.6 ~current_state:"worse"
  in
  Alcotest.(check (list functional_event_testable))
    "events"
    [ Marriage_early_stopping_core.Event.Overfit_detected { counter = 1; patience = 3 } ]
    events

let test_reset_triggered_restores_checkpoint () =
  let tracker = Marriage_early_stopping_core.Tracker.create ~patience:2 () |> Or_error.ok_exn in
  let tracker, _, _ =
    Marriage_early_stopping_core.check_atmosphere tracker ~daily_loss:0.4 ~current_state:"best"
  in
  let tracker, _, _ =
    Marriage_early_stopping_core.check_atmosphere tracker ~daily_loss:0.6 ~current_state:"worse-1"
  in
  let tracker, state, events =
    Marriage_early_stopping_core.check_atmosphere tracker ~daily_loss:0.7 ~current_state:"worse-2"
  in
  Alcotest.(check string) "restored state" "best" state;
  Alcotest.(check (list functional_event_testable))
    "events"
    [ Marriage_early_stopping_core.Event.Overfit_detected { counter = 2; patience = 2 }
    ; Marriage_early_stopping_core.Event.Reset_triggered
    ]
    events;
  Alcotest.(check int) "counter reset" 0 tracker.overfit_counter

(* --- oop (marriage_early_stopping_oop_core) --- *)

let oop_event_testable =
  Alcotest.testable
    (fun fmt e ->
      Fmt.string fmt (Sexp.to_string_hum (Marriage_early_stopping_oop_core.Event.sexp_of_t e)))
    Marriage_early_stopping_oop_core.Event.equal

let test_oop_create_rejects_non_positive_patience () =
  match Marriage_early_stopping_oop_core.Tracker.create ~patience:0 () with
  | Error err ->
    Alcotest.(check string)
      "error message" "patience должен быть положительным (patience = 0)"
      (Error.to_string_hum err)
  | Ok _ -> Alcotest.fail "expected Error for patience = 0"

let test_oop_first_day_is_always_a_checkpoint () =
  let tracker = Marriage_early_stopping_oop_core.Tracker.create ~patience:3 () |> Or_error.ok_exn in
  let state, events = tracker#check_atmosphere ~daily_loss:0.9 ~current_state:"day1" in
  Alcotest.(check string) "state unchanged" "day1" state;
  Alcotest.(check (list oop_event_testable))
    "events"
    [ Marriage_early_stopping_oop_core.Event.Checkpoint_saved { loss = 0.9 } ]
    events

let test_oop_reset_triggered_restores_checkpoint_and_resets_counter () =
  let tracker = Marriage_early_stopping_oop_core.Tracker.create ~patience:2 () |> Or_error.ok_exn in
  let (_ : string * Marriage_early_stopping_oop_core.Event.t list) =
    tracker#check_atmosphere ~daily_loss:0.4 ~current_state:"best"
  in
  let (_ : string * Marriage_early_stopping_oop_core.Event.t list) =
    tracker#check_atmosphere ~daily_loss:0.6 ~current_state:"worse-1"
  in
  let state, events = tracker#check_atmosphere ~daily_loss:0.7 ~current_state:"worse-2" in
  Alcotest.(check string) "restored state" "best" state;
  Alcotest.(check (list oop_event_testable))
    "events"
    [ Marriage_early_stopping_oop_core.Event.Overfit_detected { counter = 2; patience = 2 }
    ; Marriage_early_stopping_oop_core.Event.Reset_triggered
    ]
    events;
  Alcotest.(check int) "counter reset" 0 tracker#overfit_counter

(* --- naive (marriage_early_stopping_naive_core) --- *)

let test_naive_accepts_any_patience_without_validation () =
  let (_ : Marriage_early_stopping_naive_core.marriage_early_stopping) =
    new Marriage_early_stopping_naive_core.marriage_early_stopping ~patience:0 ()
  in
  ()

let test_naive_reproduces_original_bug_at_patience_zero () =
  let tracker = new Marriage_early_stopping_naive_core.marriage_early_stopping ~patience:0 () in
  let checkpoint_state = ref "best" in
  tracker#check_atmosphere ~daily_loss:0.4 checkpoint_state;
  let overfit_state = ref "worse" in
  tracker#check_atmosphere ~daily_loss:0.6 overfit_state;
  (* patience=0: overfit_counter=1 сразу >= patience=0 — сброс срабатывает
     на первом же оверфит-дне, а не после накопления терпения. Баг
     оригинала, воспроизведённый буквально, а не исправленный. *)
  Alcotest.(check int) "counter reset immediately (bug reproduced)" 0 tracker#overfit_counter;
  Alcotest.(check string) "state restored from checkpoint" "best" !overfit_state

let test_naive_normal_patience_behaves_as_expected () =
  let tracker = new Marriage_early_stopping_naive_core.marriage_early_stopping ~patience:3 () in
  let state = ref "best" in
  tracker#check_atmosphere ~daily_loss:0.4 state;
  Alcotest.(check (float 0.0001)) "best_relationship_loss" 0.4 tracker#best_relationship_loss;
  Alcotest.(check int) "overfit_counter" 0 tracker#overfit_counter

let () =
  Alcotest.run "marriage_early_stopping"
    [ ( "functional"
      , [ Alcotest.test_case "create rejects patience <= 0" `Quick
            test_create_rejects_non_positive_patience
        ; Alcotest.test_case "create accepts patience > 0" `Quick
            test_create_accepts_positive_patience
        ; Alcotest.test_case "first day is always a checkpoint" `Quick
            test_first_day_is_always_a_checkpoint
        ; Alcotest.test_case "overfit counter increments without reset" `Quick
            test_overfit_counter_increments_without_reset
        ; Alcotest.test_case "reset triggered restores checkpoint" `Quick
            test_reset_triggered_restores_checkpoint
        ] )
    ; ( "oop"
      , [ Alcotest.test_case "create rejects patience <= 0" `Quick
            test_oop_create_rejects_non_positive_patience
        ; Alcotest.test_case "first day is always a checkpoint" `Quick
            test_oop_first_day_is_always_a_checkpoint
        ; Alcotest.test_case "reset triggered restores checkpoint and resets counter" `Quick
            test_oop_reset_triggered_restores_checkpoint_and_resets_counter
        ] )
    ; ( "naive"
      , [ Alcotest.test_case "accepts any patience without validation" `Quick
            test_naive_accepts_any_patience_without_validation
        ; Alcotest.test_case "reproduces original bug at patience=0" `Quick
            test_naive_reproduces_original_bug_at_patience_zero
        ; Alcotest.test_case "normal patience behaves as expected" `Quick
            test_naive_normal_patience_behaves_as_expected
        ] )
    ]
