let make_pool uri =
  match Caqti_lwt.connect_pool @@ Uri.of_string uri with
  | Ok pool -> pool
  | Error _ -> failwith "Error creating DB connection pool"

let transaction query connection =
  let (module C : Caqti_lwt.CONNECTION) = connection in
  let open Lwt_result.Infix in
  C.start () >>= fun () ->
  Lwt.bind (query connection) (function
    | Ok query_result -> C.commit () >>= fun () -> Ok query_result |> Lwt.return
    | Error query_error ->
        C.rollback () >>= fun () -> Lwt_result.fail query_error)
