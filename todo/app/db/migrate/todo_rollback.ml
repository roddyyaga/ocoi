let%lwt conn = Db.connection

let result = Lwt_main.run (Queries.Todo.rollback conn)

let () =
  match result with
  | Ok () -> print_endline "Rollback successful."
  | Error err ->
      print_endline "Rollback failed!" ;
      failwith (Caqti_error.show err)
