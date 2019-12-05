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
    handler req
    >|= fun response ->
    let meth = req |> Request.meth |> Cohttp.Code.string_of_method in
    let uri = req |> Request.uri |> Uri.path_and_query in
    let code = response |> Response.code |> Cohttp.Code.string_of_status in
    let zone = Time.get_sexp_zone () in
    let time = Time.now () |> Time.to_sec_string ~zone in
    Logs.info (fun m -> m "%s \"%s\" at %s" meth uri time) ;
    Logs.info (fun m -> m "Responded with %s" code) ;
    response
  in
  Rock.Middleware.create ~name:"Ice default logger" ~filter
