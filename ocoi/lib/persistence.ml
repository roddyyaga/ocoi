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

module Engines = struct
  module Caqti : Engine with type connection = Caqti_lwt.connection = struct
    type connection = Caqti_lwt.connection

    type error = Caqti_error.t

    type 'a query_result = ('a, error) result

    module Types = struct
      include Caqti_type

      let tup = Caqti_type.tup2
    end

    let find connection arg_type row_type query =
      let query_object = Caqti_request.find arg_type row_type query in
      let do_query arg =
        let (module Db : Caqti_lwt.CONNECTION) = connection in
        Db.find query_object arg
      in
      do_query

    let find_opt connection arg_type row_type query =
      let query_object = Caqti_request.find_opt arg_type row_type query in
      let do_query arg =
        let (module Db : Caqti_lwt.CONNECTION) = connection in
        Db.find_opt query_object arg
      in
      do_query

    let collect connection arg_type row_type query =
      let query_object = Caqti_request.collect arg_type row_type query in
      let do_query arg =
        let (module Db : Caqti_lwt.CONNECTION) = connection in
        Db.fold query_object (fun row acc -> row :: acc) arg []
      in
      do_query

    let exec connection arg_type query =
      let query_object = Caqti_request.exec arg_type query in
      let do_query arg =
        let (module Db : Caqti_lwt.CONNECTION) = connection in
        Db.exec query_object arg
      in
      do_query
  end
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

module Interfaces = struct
  module Types = struct
    module type Caqti = sig
      include Interface with type Engine.connection = Caqti_lwt.connection
    end
  end

  module Bases = struct
    module Caqti = struct
      module Engine : Engine with type connection = Caqti_lwt.connection =
        Engines.Caqti
    end
  end
end

let handle_query_result ~f ~error_handler query_result =
  match%lwt query_result with
  | Ok value -> value |> f |> Lwt.return
  | Error err -> err |> error_handler

module Mappers = struct
  module Base (Interface : Interface) = struct
    open Interface

    let error_handler _ = failwith ""

    let make_collect query connection arg_type arg =
      let query_result =
        Engine.collect connection arg_type model_engine_type query arg
      in
      handle_query_result ~f:(List.map ~f:to_model) ~error_handler query_result

    let make_find query connection arg_type row_type f arg =
      let query_result = Engine.find connection arg_type row_type query arg in
      handle_query_result ~f ~error_handler query_result

    let make_find_opt query connection arg_type row_type f arg =
      let query_result =
        Engine.find_opt connection arg_type row_type query arg
      in
      handle_query_result ~f ~error_handler query_result

    let make_exec query connection arg_type f arg =
      let query_result = Engine.exec connection arg_type query arg in
      handle_query_result ~f ~error_handler query_result
  end

  module Crud (Interface : Interface) = struct
    open Interface
    module Base = Base (Interface)

    let make_all query connection =
      Base.make_collect query connection Engine.Types.unit ()

    let make_show query connection id =
      Base.make_find_opt query connection Engine.Types.int model_engine_type
        (Option.map ~f:to_model) id

    let make_create query connection create_arg =
      Base.make_find query connection creation_engine_type Engine.Types.int
        ident create_arg

    let make_update query connection updated_instance =
      Base.make_exec query connection model_engine_type ident updated_instance

    let make_destroy query connection id =
      Base.make_exec query connection Engine.Types.int ident id
  end

  module Migrations (Interface : Interface) = struct
    open Interface
    module Base = Base (Interface)

    let make query connection =
      Base.make_exec query connection Engine.Types.unit ident
  end
end

(*
module Example_interface : Interfaces.Types.Caqti = struct
  include Interfaces.Bases.Caqti

  type model = {id: int; name: string}

  type model_type = int * string

  let model_engine_type = Engine.Types.(tup int string)

  type creation_type = int * int

  let creation_engine_type = Engine.Types.(tup int int)

  let from_model {id; name} = (id, name)

  let to_model (id, name) = {id; name}
end

module Example_mapper = Mappers.Crud (Example_interface)

let show =
  Example_mapper.make_show
    {sql| SELECT id, name FROM models WHERE id = (?) |sql}

type um_creation_type = int * (string * string)

module Um_interface :
  Interfaces.Types.Caqti with type creation_type = um_creation_type = struct
  include Interfaces.Bases.Caqti

  type model = {id: int; user_id: int; email: string; password_hash: string}

  type model_type = int * (int * (string * string))

  let model_engine_type = Engine.Types.(tup int (tup int (tup string string)))

  type creation_type = um_creation_type

  let creation_engine_type = Engine.Types.(tup int (tup string string))

  let from_model {id; user_id; email; password_hash} =
    (id, (user_id, (email, password_hash)))

  let to_model (id, (user_id, (email, password_hash))) =
    {id; user_id; email; password_hash}
end

module Um_mapper = Mappers.Crud (Um_interface)

let all =
  Um_mapper.make_all
    {sql| SELECT id, user_id, email, password_hash FROM user_meta |sql}

let create connection ~user_id ~email ~password_hash =
  Um_mapper.make_create
    {sql| INSERT INTO user_meta (user_id, email, password_hash) VALUES (?, ?, ?) RETURNING id |sql}
    connection
    (user_id, (email, password_hash))

let show =
  Um_mapper.make_show
    {sql| SELECT id, user_id, email, password_hash
          FROM user_meta
          WHERE id = (?)
    |sql}

let update =
  Um_mapper.make_update
    {sql| UPDATE user_meta
       SET (user_id, email, password_hash) = (?, ?, ?)
       WHERE id = (?)
    |sql}
    *)
