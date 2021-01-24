open Base
open Opium.Std

let () =
  let app = Ocoi.App.base in
  let reporter = Logs_fmt.reporter () in
  Logs.set_reporter reporter;
  Logs.set_level (Some Logs.Info);
  app |> Ocoi.App.register Handlers.handlers |> App.run_command
