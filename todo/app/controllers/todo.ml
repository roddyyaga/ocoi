let%lwt conn = Db.connection

let create ~title ~completed = Queries.Todo.create conn ~title ~completed

module Rud : Ocoi.Controllers.Rud = struct
  include Models.Todo

  let index () = Queries.Todo.all conn

  let show id = Queries.Todo.show conn id

  let update {id; title; completed} =
    Queries.Todo.update conn {id; title; completed}

  let destroy id = Queries.Todo.destroy conn id
end
