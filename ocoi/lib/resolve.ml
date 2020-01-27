open Core
open Opium.Std

let resolve error_handler value_result_lwt f =
  match%lwt value_result_lwt with
  | Ok value -> value |> f |> respond'
  | Error err -> err |> error_handler |> respond' ~code:`Internal_server_error

let string_id value_result_lwt f =
  resolve (fun s -> `String s) value_result_lwt f

let ignore value_result_lwt f =
  resolve (fun _ -> `String "An error occurred") value_result_lwt f
