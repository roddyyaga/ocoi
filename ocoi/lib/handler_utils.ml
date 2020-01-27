open Core
open Opium.Std

let empty_response code = `String "" |> respond' ~code

let empty_created_response location =
  `String ""
  |> respond'
       ~headers:(Cohttp.Header.of_list [ ("Location", location) ])
       ~code:`Created

let respond_bad_request_400 err = `String err |> respond' ~code:`Bad_request

let id_path name = name ^ "/:id"

