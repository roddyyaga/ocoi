open Core
open Opium.Std

let hello_world =
  get "/" (fun _ ->
      `String "Hello world!\n\nfrom OCaml\n     Ice" |> respond')

let _ =
  let app = App.empty in
  let reporter = Logs_fmt.reporter () in
  Logs.set_reporter reporter ;
  Logs.set_level (Some Logs.Info) ;
  let app = app |> hello_world in
  app |> middleware Ocoi.Logging.default_logger |> App.run_command
