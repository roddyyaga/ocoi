open Base
open Opium

type my_body = [ `Json of Yojson.Safe.t | `String of string | `Empty ]

let to_body = function
  | `String s -> Body.of_string s
  | `Empty -> Body.empty
  | `Json j -> j |> Yojson.Safe.to_string |> Body.of_string

let respond ?headers ?status body =
  Response.make ?headers ?status ~body:(to_body body) () |> Lwt.return

let rec jingoo_value_of_yojson =
  let open Jingoo.Jg_types in
  function
  | `Assoc pairs ->
      Tobj (List.map ~f:(fun (k, v) -> (k, jingoo_value_of_yojson v)) pairs)
  | `Bool b -> Tbool b
  | `Float f -> Tfloat f
  | `Int i -> Tint i
  | `Intlit s -> Tint (Int.of_string s)
  | `List xs -> Tlist (List.map ~f:jingoo_value_of_yojson xs)
  | `Null -> Tnull
  | `String s -> Tstr s
  | `Tuple xs -> Tlist (List.map ~f:jingoo_value_of_yojson xs)
  | `Variant (tag, value) ->
      let v = Option.value value ~default:`Null in
      Tobj [ (tag, jingoo_value_of_yojson v) ]

let jingoo_model_of_yojson = function
  | `Assoc pairs ->
      List.map pairs ~f:(fun (k, v) -> (k, jingoo_value_of_yojson v))
  | _ ->
      failwith
        "Expected yojson object to convert to jingoo, but got some other JSON \
         value."

(* TODO - form encoding decoding *)
