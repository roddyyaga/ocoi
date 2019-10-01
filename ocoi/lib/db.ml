let handle_caqti_result result =
  match%lwt result with
  | Ok data -> Lwt.return data
  | Error err -> failwith (Caqti_error.show err)

let get_connection uri =
    let uri = Uri.of_string uri in
    let db_connection_future = Caqti_lwt.connect uri in
    handle_caqti_result db_connection_future
