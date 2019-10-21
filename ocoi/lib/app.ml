open Core
open Opium.Std

let base = App.empty |> middleware Logging.default_logger
