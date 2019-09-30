let connection_uri =
  Uri.of_string "postgresql://postgres:12345@localhost:5433/postgres"

type error = Database_error of string

let or_error m =
  match%lwt m with
  | Ok a -> Ok a |> Lwt.return
  | Error e -> Error (Database_error (Caqti_error.show e)) |> Lwt.return

let%lwt db_connection_future = Caqti_lwt.connect connection_uri

let connection =
  match db_connection_future with
  | Ok conn -> conn
  | Error err -> failwith (Caqti_error.show err)
