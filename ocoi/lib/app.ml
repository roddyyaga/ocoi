open Core
open Opium.Std

let base =
  App.empty
  |> middleware Logging.default_logger
  |> middleware (Ocoi_middleware.allow_cors ())
