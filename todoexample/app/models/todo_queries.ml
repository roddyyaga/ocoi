open Todo

let all_query =
  Caqti_request.collect Caqti_type.unit
    Caqti_type.(tup3 int string bool)
    {sql| SELECT id, title, completed FROM todo |sql}

let all (module Db : Caqti_lwt.CONNECTION) =
  Db.fold all_query
    (fun (id, title, completed) acc -> {id; title; completed} :: acc)
    () []

let show_query =
  Caqti_request.find_opt Caqti_type.int
    Caqti_type.(tup3 int string bool)
    {sql| SELECT id, title, completed
       FROM todo
       WHERE id = (?)
    |sql}

let show (module Db : Caqti_lwt.CONNECTION) id =
  let result = Db.find_opt show_query id in
  match%lwt result with
  | Ok data ->
      let record =
        match data with
        | Some (id, title, completed) -> Some {id; title; completed}
        | None -> None
      in
      Lwt.return record
  | Error _ -> failwith "Error in show query"

let create_query =
  Caqti_request.find
    Caqti_type.(tup2 string bool)
    Caqti_type.int
    {sql| INSERT INTO todo (title, completed) VALUES (?, ?) RETURNING id |sql}

let create (module Db : Caqti_lwt.CONNECTION) ~title ~completed =
  Db.find create_query (title, completed)

let update_query =
  Caqti_request.exec
    Caqti_type.(tup3 string bool int)
    {| UPDATE todo
       SET (title, completed) = (?, ?)
       WHERE id = (?)
    |}

let update (module Db : Caqti_lwt.CONNECTION) {id; title; completed} =
  Db.exec update_query (title, completed, id)

let destroy_query =
  Caqti_request.exec Caqti_type.int {sql| DELETE FROM todo WHERE id = (?) |sql}

let destroy (module Db : Caqti_lwt.CONNECTION) id = Db.exec destroy_query id
