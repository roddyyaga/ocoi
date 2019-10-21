(** Defines Opium middlewares for use in Ice apps *)

open Opium.Std
open Core

val allow_cors :
  ?origin:string -> ?methods:string sexp_list -> unit -> Rock.Middleware.t
(** [allow_cors origin methods] enables {{: https://en.wikipedia.org/wiki/Cross-origin_resource_sharing} Cross-Origin
    Resource Sharing} for requests from [origin] with methods in the list [methods].

   If [origin] is not given it defaults to all origins (the wildcard value ["*"]). If [methods] is not given it defaults
   to all methods. *)
