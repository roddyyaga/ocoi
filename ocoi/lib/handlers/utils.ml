open Opium.Std

type my_body = [ `Json of Yojson.Safe.t | `String of string | `Empty ]

let to_body = function
  | `String s -> Body.of_string s
  | `Empty -> Body.empty
  | `Json j -> j |> Yojson.Safe.to_string |> Body.of_string

let respond ?headers ?status body =
  Response.make ?headers ?status ~body:(to_body body) () |> Lwt.return
