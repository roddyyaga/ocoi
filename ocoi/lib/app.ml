open Base
open Opium.Std

let base = App.empty |> middleware Logging.default_logger

let register handlers app =
  List.fold ~init:app ~f:(fun app' handler -> handler app') handlers
