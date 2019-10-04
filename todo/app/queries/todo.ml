open Models.Todo

let all_query =
  Caqti_request.collect Caqti_type.unit
    Caqti_type.(tup3 int string bool)
    {sql| SELECT id, title, completed FROM todo |sql}

let all (module Db : Caqti_lwt.CONNECTION) =
  let result =
    Db.fold all_query
      (fun (id, title, completed) acc -> {id; title; completed} :: acc)
      () []
  in
  Ocoi.Db.handle_caqti_result result

let show_query =
  Caqti_request.find_opt Caqti_type.int
    Caqti_type.(tup3 int string bool)
    {sql| SELECT id, title, completed
          FROM todo
          WHERE id = (?)
    |sql}

let show (module Db : Caqti_lwt.CONNECTION) id =
  let result = Db.find_opt show_query id in
  let%lwt data = Ocoi.Db.handle_caqti_result result in
  let record =
    match data with
    | Some (id, title, completed) -> Some {id; title; completed}
    | None -> None
  in
  Lwt.return record

let create_query =
  Caqti_request.find
    Caqti_type.(tup2 string bool)
    Caqti_type.int
    {sql| INSERT INTO todo (title, completed) VALUES (?, ?) RETURNING id |sql}

let create (module Db : Caqti_lwt.CONNECTION) ~title ~completed =
  let result = Db.find create_query (title, completed) in
  Ocoi.Db.handle_caqti_result result

let update_query =
  Caqti_request.exec
    Caqti_type.(tup3 string bool int)
    {| UPDATE todo
       SET (title, completed) = (?, ?)
       WHERE id = (?)
    |}

let update (module Db : Caqti_lwt.CONNECTION) {id; title; completed} =
  let result = Db.exec update_query (title, completed, id) in
  Ocoi.Db.handle_caqti_result result

let destroy_query =
  Caqti_request.exec Caqti_type.int {sql| DELETE FROM todo WHERE id = (?) |sql}

let destroy (module Db : Caqti_lwt.CONNECTION) id =
  let result = Db.exec destroy_query id in
  Ocoi.Db.handle_caqti_result result
let migrate_query =
  Caqti_request.exec Caqti_type.unit
   {| CREATE TABLE todo (
         id SERIAL PRIMARY KEY NOT NULL,
         title VARCHAR NOT NULL,
         completed BOOLEAN NOT NULL
       )
    |}

let migrate (module Db : Caqti_lwt.CONNECTION) = Db.exec migrate_query ()

let rollback_query = Caqti_request.exec Caqti_type.unit {| DROP TABLE todo |}

let rollback (module Db : Caqti_lwt.CONNECTION) = Db.exec rollback_query ()
