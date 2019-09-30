open Models
open Todo

let example_todo =
  {id = 1; title = "Do some example thing 7"; completed = false}

let index () = Todo_queries.all Db.connection

let show id = Todo_queries.show Db.connection id

let create ~title ~completed =
  Todo_queries.create Db.connection ~title ~completed

let update {id; title; completed} =
  Todo_queries.update Db.connection {id; title; completed}

let destroy id = Todo_queries.destroy Db.connection id

let create_example () =
  Todo_queries.create Db.connection ~title:"DB example" ~completed:false

let do_migration () = Todo_migration_queries.migrate Db.connection
