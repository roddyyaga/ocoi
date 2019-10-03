(** Provides functionality for defining Ice controllers and registering them with an Opium app. *)

open Opium.Std

(** Represents Read, Update and Delete operations on some model [t]

    Example use:
        Given a model [type t = {id: int; title: string; completed: bool} [@@deriving yojson]] defined in [models/todo.ml] with RUD functionality for the database implemented in [queries/todo.ml], you would define a module in [controllers/todo.ml] with this signature like so:
    {[module Rud : Ocoi.Controllers.Rud = struct
  include Models.Todo

  let index () = Queries.Todo.all conn

  let show id = Queries.Todo.show conn id

  let update {id; title; completed} =
    Queries.Todo.update conn {id; title; completed}

  let destroy id = Queries.Todo.destroy conn id
end]}
    and then register it [main.ml] with [Ocoi.Controllers.register_rud "/todos" (module Todo.Rud) app]. This creates a
    REST API at [/todos] and [/todos/:id] with the expected functionality.

    The C of CRUD (Create) is missing because the type of a create function (for instance [create ~title ~completed =
        Queries.Todo.create conn ~title ~completed]) depends on the structure of [t].
*)
module type Rud = sig
  type t
  (** The model type *)

  val to_yojson : t -> Yojson.Safe.t
  (** Converts the model type to JSON (typically automatically generated with [[@@deriving yojson]]) *)

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
  (** Produces a model instance from JSON (typically automatically generated with [[@@deriving yojson]]) *)

  val index : unit -> t list Lwt.t
  (** [index ()] gets all stored instances of the model *)

  val show : int -> t option Lwt.t
  (** [show id] returns [Some m] if there is some model [m] with id [id] stored, and [None] otherwise *)

  val update : t -> unit Lwt.t
  (** [update new_model] updates the stored model with the id of [new_model] to match it *)

  val destroy : int -> unit Lwt.t
  (** [destroy id] deletes the model with id [id] from the database *)
end

val index_handler : string -> (module Rud) -> App.builder
(** [app |> index_handler "name" (module Rud)] exposes [Rud.index] at [GET /name] *)

val show_handler : string -> (module Rud) -> App.builder
(** [app |> show_handler "name" (module Rud)] exposes [Rud.show] at [GET /name/:id] *)

val update_handler : string -> (module Rud) -> App.builder
(** [app |> update_handler "name" (module Rud)] exposes [Rud.update] at [PUT /name]

    Note that this differs from the conventional location of [PUT /name/:id] for the Update operation of CRUD. This is
    because the ID of the new model will always be supplied in the body, so doesn't need to be put in the URL too. *)

val destroy_handler : string -> (module Rud) -> App.builder
(** [app |> destroy_handler "name" (module Rud)] exposes [Rud.destroy] at [Delete /name/:id] *)

val register_rud : string -> (module Rud) -> App.t -> App.t
(** [register_rud "name" (module Rud) app] calls [index_handler], [show_handler], [update_handler] and [destroy_handler]
     on [app]. *)
