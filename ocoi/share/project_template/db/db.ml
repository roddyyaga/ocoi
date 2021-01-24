open Core

let hostname =
  match Sys.getenv "POSTGRES_HOSTNAME" with Some s -> s | None -> "localhost"

let pool =
  Ocoi.Db.make_pool
    (Printf.sprintf "postgresql://postgres:12345@%s:5432/postgres" hostname)

let execute query = Caqti_lwt.Pool.use query pool
