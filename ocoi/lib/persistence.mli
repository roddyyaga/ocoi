open Core

module type Engine = sig
  type connection

  type error

  type 'a query_result = ('a, error) result

  module Types : sig
    type 'a t

    val unit : unit t

    val int : int t

    val bool : bool t

    val string : string t

    val tup : 'a t -> 'b t -> ('a * 'b) t
  end

  val find :
    connection ->
    'a Types.t ->
    'b Types.t ->
    string ->
    'a ->
    'b query_result Lwt.t

  val find_opt :
    connection ->
    'a Types.t ->
    'b Types.t ->
    string ->
    'a ->
    'b option query_result Lwt.t

  val collect :
    connection ->
    'a Types.t ->
    'b Types.t ->
    string ->
    'a ->
    'b list query_result Lwt.t

  val exec :
    connection -> 'a Types.t -> string -> 'a -> unit query_result Lwt.t
end

module Engines : sig
  module Caqti : Engine with type connection = Caqti_lwt.connection
end

module type Interface = sig
  type model

  module Engine : Engine

  type model_type

  val model_engine_type : model_type Engine.Types.t

  type creation_type

  val creation_engine_type : creation_type Engine.Types.t

  val from_model : model -> model_type

  val to_model : model_type -> model
end

module Interfaces : sig
  module Types : sig
    module type Caqti = sig
      include Interface with type Engine.connection = Caqti_lwt.connection
    end
  end

  module Bases : sig
    module Caqti : sig
      module Engine : Engine with type connection = Caqti_lwt.connection
    end
  end
end

val handle_query_result :
  f:('a -> 'b) ->
  error_handler:('c -> 'b Lwt.t) ->
  ('a, 'c) result Lwt.t ->
  'b Lwt.t

module Mappers : sig
  module Base (Interface : Interface) : sig
    val make_collect :
      string ->
      Interface.Engine.connection ->
      'a Interface.Engine.Types.t ->
      'a ->
      Interface.model list Lwt.t

    val make_find :
      string ->
      Interface.Engine.connection ->
      'a Interface.Engine.Types.t ->
      'b Interface.Engine.Types.t ->
      ('b -> 'c) ->
      'a ->
      'c Lwt.t

    val make_find_opt :
      string ->
      Interface.Engine.connection ->
      'a Interface.Engine.Types.t ->
      'b Interface.Engine.Types.t ->
      ('b option -> 'c) ->
      'a ->
      'c Lwt.t

    val make_exec :
      string ->
      Interface.Engine.connection ->
      'a Interface.Engine.Types.t ->
      (unit -> 'b) ->
      'a ->
      'b Lwt.t
  end

  module Crud (Interface : Interface) : sig
    val make_all :
      string -> Interface.Engine.connection -> Interface.model list Lwt.t

    val make_show :
      string ->
      Interface.Engine.connection ->
      int ->
      Interface.model option Lwt.t

    val make_create :
      string ->
      Interface.Engine.connection ->
      Interface.creation_type ->
      int Lwt.t

    val make_update :
      string ->
      Interface.Engine.connection ->
      Interface.model_type ->
      unit Lwt.t

    val make_destroy :
      string -> Interface.Engine.connection -> int -> unit Lwt.t
  end

  module Migrations (Interface : Interface) : sig
    val make : string -> Interface.Engine.connection -> unit -> unit Lwt.t
  end
end
