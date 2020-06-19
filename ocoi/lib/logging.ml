(** Defines various loggers for Ice apps. *)

open Core
open Lwt.Infix
open Opium.Std

(* TODO - define/make configurable to give different levels of details *)
(* TODO - enable logging of parameters (possibly implement elsewhere) *)
(* TODO - log duration of requests *)
(* TODO - make logging work for requests that error *)
let default_logger =
  let filter handler req =
    handler req >|= fun response ->
    let meth = req.Request.meth |> Httpaf.Method.to_string in
    let uri = req.Request.target |> Uri.of_string |> Uri.path_and_query in
    let code = response.Response.status |> Httpaf.Status.to_string in
    let zone = Time.get_sexp_zone () in
    let time = Time.now () |> Time.to_sec_string ~zone in
    Logs.info (fun m -> m "%s \"%s\" at %s" meth uri time);
    Logs.info (fun m -> m "Responded with %s" code);
    response
  in
  Rock.Middleware.create ~name:"Ice default logger" ~filter
