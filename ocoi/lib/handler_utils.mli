(** Utility functions for handling requests to an Opium app. *)

open Opium.Std

val empty_response : Cohttp.Code.status_code -> Response.t Lwt.t
(** [empty_response code] returns an empty response with a code of [code] *)

val empty_created_response : string -> Response.t Lwt.t
(** [empty_created_response location] returns an empty response with the [Location] header set to [location]

    The code will be [201 Created].*)

val respond_bad_request_400 : string -> Response.t Lwt.t
(** [respond_bad_request err] returns a [400 Bad Request] response with [err] as the content *)

val id_path : string -> string
(** [id_path "name"] returns ["name/:id"] *)
