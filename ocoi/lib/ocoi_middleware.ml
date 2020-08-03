open Core
open Lwt.Infix
open Opium.Std

let add_cors_headers ?origin ?methods (headers : Httpaf.Headers.t) :
    Httpaf.Headers.t =
  let vary_header =
    match origin with Some _ -> [ ("vary", "Origin") ] | None -> []
  in
  let origin_value = Option.value origin ~default:"*" in
  let methods_list =
    Option.value methods
      ~default:[ "GET"; "HEAD"; "POST"; "DELETE"; "OPTIONS"; "PUT"; "PATCH" ]
  in
  let methods_value = String.concat ~sep:", " methods_list in
  let new_headers =
    [
      ("access-control-allow-origin", origin_value);
      ("access-control-allow-headers", "Accept, Content-Type, Authorization");
      ("access-control-allow-methods", methods_value);
    ]
    @ vary_header
  in
  Httpaf.Headers.add_list headers new_headers

let allow_cors ?origin ?methods () =
  let filter handler req =
    handler req >|= fun response ->
    let new_headers =
      response.Response.headers |> add_cors_headers ?origin ?methods
    in
    { response with Response.headers = new_headers }
  in
  Rock.Middleware.create ~name:"Ice CORS enabler" ~filter
