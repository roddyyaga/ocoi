(** Provides functionality for defining Ice controllers and registering them with an Opium app *)

open Core
open Opium.Std

(** Represents Create, Read, Update and Delete operations on some model [t]

    Example use:
    Given a model [type t = {id: int; title: string; completed: bool} [@@deriving yojson]] defined in
    [models/todo.ml] with CRUD functionality for the database implemented in [queries/todo.ml], you would define a module in [controllers/todo.ml] with this signature like so:
{[module Crud : Ocoi.Controllers.Crud = struct
  include Models.Todo

  let create json =
    let open Yojson.Safe.Util in
    let title = json |> member "title" |> to_string in
    let completed = json |> member "completed" |> to_bool in
    Queries.Todo.create conn ~title ~completed

  let index () = Queries.Todo.all conn

  let show id = Queries.Todo.show conn id

  let update {id; title; completed} =
    Queries.Todo.update conn {id; title; completed}

  let destroy id = Queries.Todo.destroy conn id
end]}
    and then register it [main.ml] with [Ocoi.Controllers.register_crud "/todos" (module Todo.Crud) app]. This creates a
    REST API at [/todos] and [/todos/:id] with the expected functionality.
*)
module type Crud = sig
  type t
  (** The model type *)

  val to_yojson : t -> Yojson.Safe.t
  (** Converts the model type to JSON (typically automatically generated with [[@@deriving yojson]]) *)

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
  (** Produces a model instance from JSON (typically automatically generated with [[@@deriving yojson]]) *)

  val create : Yojson.Safe.t -> int Lwt.t
  (** [create json] stores a new model in the database (probably initialised with data from [json]) and returns its id *)

  val index : unit -> t list Lwt.t
  (** [index ()] gets all stored instances of the model *)

  val show : int -> t option Lwt.t
  (** [show id] returns [Some m] if there is some model [m] with id [id] stored, and [None] otherwise *)

  val update : t -> unit Lwt.t
  (** [update new_model] updates the stored model with the id of [new_model] to match it *)

  val destroy : int -> unit Lwt.t
  (** [destroy id] deletes the model with id [id] from the database *)
end

val create_handler :
  string ->
  (Yojson.Safe.t -> int Lwt.t) ->
  ?wrapper:((Request.t -> Response.t Lwt.t) -> Rock.Handler.t) ->
  Opium.App.builder
(** [app |> create_handler "name" Crud.create] exposes [Crud.create] at [POST /name]

    Each handler creation function has an optional [wrapper] argument, which if provided will be used to modify the
    handler function. This can be used to do things like adding authentication. *)

val index_handler :
  string ->
  (unit -> 'a sexp_list Lwt.t) ->
  ('a -> Yojson.Safe.t) ->
  ?wrapper:((Request.t -> Response.t Lwt.t) -> Rock.Handler.t) ->
  Opium.App.builder
(** [app |> index_handler "name" Crud.index Crud.to_yojson] exposes [Crud.index] at [GET /name] *)

val show_handler :
  string ->
  (int -> 'a option Lwt.t) ->
  ('a -> Yojson.Safe.t) ->
  ?wrapper:((Request.t -> Response.t Lwt.t) -> Rock.Handler.t) ->
  Opium.App.builder
(** [app |> show_handler "name" Crud.show to_yojson] exposes [Crud.show] at [GET /name/:id] *)

val update_handler :
  string ->
  ('a -> unit Lwt.t) ->
  (Yojson.Safe.t -> ('a, string) result) ->
  ?wrapper:((Request.t -> Response.t Lwt.t) -> Rock.Handler.t) ->
  Opium.App.builder
(** [app |> update_handler "name" Crud.update Crud.of_yojson] exposes [Crud.update] at [PUT /name]

    Note that this differs from the conventional location of [PUT /name/:id] for the Update operation of CRUD. This is
    because the ID of the new model will always be supplied in the body, so doesn't need to be put in the URL too. *)

val destroy_handler :
  string ->
  (int -> unit Lwt.t) ->
  ?wrapper:((Request.t -> Response.t Lwt.t) -> Rock.Handler.t) ->
  Opium.App.builder
(** [app |> destroy_handler "name" Crud.destroy] exposes [Crud.destroy] at [Delete /name/:id] *)

val register_crud : string -> (module Crud) -> App.t -> App.t
(** [register_crud "name" (module Crud) app] calls [index_handler], [show_handler], [update_handler] and [destroy_handler]
     on [app]. *)

(* TODO - document these *)
val create_request_fun :
  string -> (Yojson.Safe.t -> int Lwt.t) -> Request.t -> Response.t Lwt.t

val index_request_fun :
  (unit -> 'a sexp_list Lwt.t) ->
  ('a -> Yojson.Safe.t) ->
  'b ->
  Response.t Lwt.t

val show_request_fun :
  (int -> 'a option Lwt.t) ->
  ('a -> Yojson.Safe.t) ->
  Request.t ->
  Response.t Lwt.t

val update_request_fun :
  ('a -> unit Lwt.t) ->
  (Yojson.Safe.t -> ('a, string) result) ->
  Request.t ->
  Response.t Lwt.t

val destroy_request_fun : (int -> unit Lwt.t) -> Request.t -> Response.t Lwt.t
