Caqti_request.collect Caqti_type.unit
    Caqti_type.(tup4 int int bool string)
    {sql| SELECT id, bla, is_something, another_field FROM test |sql}

let all (module Db : Caqti_lwt.CONNECTION) =
  Db.fold all_query
    (fun (id, bla, is_something, another_field) acc ->
      {id; bla; is_something; another_field} :: acc)
    () []

let show_query =
  Caqti_request.find_opt Caqti_type.int
    Caqti_type.(tup4 int int bool string)
    {sql| SELECT id, bla, is_something, another_field
       FROM test
       WHERE id = (?)
    |sql}

let show (module Db : Caqti_lwt.CONNECTION) id =
  let result = Db.find_opt show_query id in
  match%lwt result with
  | Ok data ->
      let record =
        match data with
        | Some (id, bla, is_something, another_field) -> Some {id; bla; is_something; another_field}
        | None -> None
      in
      Lwt.return record
  | Error _ -> failwith "Error in show query"

let create_query =
  Caqti_request.find
    Caqti_type.(tup3 int bool string)
    Caqti_type.int
    {sql| INSERT INTO test (bla, is_something, another_field) VALUES (?, ?, ?) RETURNING id |sql}

let create (module Db : Caqti_lwt.CONNECTION) ~bla ~is_something ~another_field =
    Db.find create_query (bla, is_something, another_field)

let update_query =
  Caqti_request.exec
    Caqti_type.(tup4 int bool string int)
    {| UPDATE test
       SET (bla, is_something, another_field) = (?, ?, ?)
       WHERE id = (?)
    |}

let update (module Db : Caqti_lwt.CONNECTION) id ~bla ~is_something ~another_field =
    Db.exec update_query (id, bla, is_something, another_field, id)

let destroy_query =
  Caqti_request.exec Caqti_type.int
    {sql| DELETE FROM test WHERE id = (?) |sql}

let destroy (module Db : Caqti_lwt.CONNECTION) id = Db.exec destroy_query id
