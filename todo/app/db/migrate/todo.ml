let%lwt conn = Db.connection

let result = Lwt_main.run (Models.Todo_migration_queries.migrate conn)

let () =
  match result with
  | Ok () -> print_endline "Migration successful."
  | Error err ->
      print_endline "Migration failed!" ;
      failwith (Caqti_error.show err)
