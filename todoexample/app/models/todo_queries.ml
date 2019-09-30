open Todo

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
  match%lwt result with
  | Ok data -> data |> Lwt.return
  | Error _ -> failwith "Error in index query"

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
  | Error err -> failwith (Caqti_error.show err)

let create_query =
  Caqti_request.find
    Caqti_type.(tup2 string bool)
    Caqti_type.int
    {sql| INSERT INTO todo (title, completed) VALUES (?, ?) RETURNING id |sql}

let create (module Db : Caqti_lwt.CONNECTION) ~title ~completed =
  let result = Db.find create_query (title, completed) in
  match%lwt result with
  | Ok data -> data |> Lwt.return
  | Error err -> failwith (Caqti_error.show err)

let update_query =
  Caqti_request.exec
    Caqti_type.(tup3 string bool int)
    {| UPDATE todo
       SET (title, completed) = (?, ?)
       WHERE id = (?)
    |}

let update (module Db : Caqti_lwt.CONNECTION) {id; title; completed} =
  let result = Db.exec update_query (title, completed, id) in
  match%lwt result with
  | Ok data -> data |> Lwt.return
  | Error err -> failwith (Caqti_error.show err)

let destroy_query =
  Caqti_request.exec Caqti_type.int {sql| DELETE FROM todo WHERE id = (?) |sql}

let destroy (module Db : Caqti_lwt.CONNECTION) id =
  let result = Db.exec destroy_query id in
  match%lwt result with
  | Ok data -> data |> Lwt.return
  | Error err -> failwith (Caqti_error.show err)
