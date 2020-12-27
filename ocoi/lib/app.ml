open Base
open Opium

let base = App.empty |> App.middleware Middleware.logger

let register handlers app =
  List.fold ~init:app ~f:(fun app' handler -> handler app') handlers
