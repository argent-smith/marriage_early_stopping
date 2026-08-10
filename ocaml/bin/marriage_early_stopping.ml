open Core

let () =
  match Marriage_early_stopping_core.run () with
  | Ok () -> ()
  | Error err -> prerr_endline [%string "Ошибка: %{Error.to_string_hum err}"]
