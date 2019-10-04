let%lwt conn = Db.connection

module Crud : Ocoi.Controllers.Crud = struct
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
end
