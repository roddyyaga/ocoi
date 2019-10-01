let connection_uri =
  Uri.of_string "postgresql://postgres:12345@localhost:5433/postgres"

let connection =
  match%lwt Caqti_lwt.connect connection_uri with
  | Ok conn -> conn |> Lwt.return
  | Error err -> failwith (Caqti_error.show err)
