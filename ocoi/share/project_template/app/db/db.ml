open Core

let hostname =
  match Sys.getenv "POSTGRES_HOSTNAME" with Some s -> s | None -> "localhost"

let connection =
  Ocoi.Db.get_connection
    (Printf.sprintf "postgresql://postgres:12345@%s:5432/postgres" hostname)
