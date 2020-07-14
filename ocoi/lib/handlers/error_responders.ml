open Base
open Utils

let caqti_error_responder error =
  let error_message = error |> Caqti_error.show in
  Logs.err (fun m -> m "%s" error_message);
  `String "See server logs for error details"
  |> respond ~status:`Internal_server_error

let caqti_query_error_message (error : Caqti_error.query_error) =
  let open Caqti_error in
  pp_msg Caml.Format.str_formatter error.msg;
  Caml.Format.flush_str_formatter ()

let generic_error_log_message =
  "Other: Unknown error occurred. You should probably use a different error \
   responder that will handle this case properly."

let prod_error_message_to_client = `String "See server logs for error details"

let respond_error ?(prod = true) () =
  ignore prod;
  prod_error_message_to_client |> respond ~status:`Internal_server_error

let caqti_error_handle_409_on_duplicate caqti_msg_string =
  let trimmed =
    caqti_msg_string |> String.chop_prefix_exn ~prefix:"ERROR:" |> String.lstrip
  in
  match
    String.is_prefix ~prefix:"duplicate key value violates unique constraint"
      trimmed
  with
  | true -> `String "" |> respond ~status:`Conflict
  | false -> respond_error ()

let basic _error =
  Logs.err (fun m -> m "Other: %s" generic_error_log_message);
  respond_error ()

let caqti_general error =
  let () =
    match error with
    | #Caqti_error.t as caqti_error ->
        Logs.err (fun m -> m "Caqti: %s" (Caqti_error.show caqti_error))
    | _other_error ->
        Logs.err (fun m -> m "Caqti: %s" generic_error_log_message)
  in
  respond_error ()

let parameters error =
  let () =
    match error with
    | `Jwt `Signature_mismatch ->
        Logs.err (fun m -> m "JWT: incorrect signature")
    | `Jwt `Format_error -> Logs.err (fun m -> m "JWT: incorrect format")
    | `Jwt `Absent -> Logs.err (fun m -> m "JWT: unexpectedly absent")
    | `Jwt `No_expiry ->
        Logs.err (fun m ->
            m
              "JWT: should have expiry but doesn't (or expiry is not an \
               integer timestamp)")
    | `Jwt `Expired -> Logs.err (fun m -> m "JWT: is expired")
    | `Json (`Parsing s) ->
        Logs.err (fun m -> m {|JSON: Could not parse "%s"|} s)
    | `Json (`Conversion (e, json)) ->
        Logs.err (fun m ->
            m {|JSON: Could not convert "%s" to the required type (%s)|}
              (Yojson.Safe.to_string ~std:true json)
              (Exn.to_string e))
  in
  respond_error ()

let caqti_409_on_duplicate error =
  match error with
  | #Caqti_error.t as error -> (
      Logs.err (fun m -> m "%s" (Caqti_error.show error));
      match error with
      | `Request_failed err ->
          let msg_string = caqti_query_error_message err in
          caqti_error_handle_409_on_duplicate msg_string
      | _ ->
          prod_error_message_to_client |> respond ~status:`Internal_server_error
      )
  | #Parameters.error as error -> parameters error
  | other_error -> basic other_error

let default = caqti_409_on_duplicate
