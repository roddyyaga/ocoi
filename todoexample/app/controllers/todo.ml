open Db
open Models
open Todo

let example_todo = {id = 1; title = "Do some example thing"; completed = false}

let index () =
  let results = Todo_queries.all Connection.db_connection in
  match%lwt results with
  | Ok (r :: _) -> r |> Lwt.return
  | Error _ -> failwith "index error"
  | _ -> failwith "No results or something"

let show id = Todo_queries.show Connection.db_connection id

let create_example () =
  Todo_queries.create Connection.db_connection ~title:"DB example"
    ~completed:false

let do_migration () = Todo_migration_queries.migrate Connection.db_connection
