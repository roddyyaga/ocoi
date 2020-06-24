open Opium.Std
open Base
open Ocoi_api
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

module Error_responders = struct
  let generic_error_log_message =
    "Unknown (non-Caqti) error occurred. You should probably use a different \
     error responder that will handle this case properly."

  let prod_error_message_to_client = `String "See server logs for error details"

  let caqti_error_handle_409_on_duplicate caqti_msg_string =
    let trimmed =
      caqti_msg_string
      |> String.chop_prefix_exn ~prefix:"ERROR:"
      |> String.lstrip
    in
    match
      String.is_prefix ~prefix:"duplicate key value violates unique constraint"
        trimmed
    with
    | true -> `String "" |> respond ~status:`Conflict
    | false ->
        prod_error_message_to_client |> respond ~status:`Internal_server_error

  let basic _error =
    Logs.err (fun m -> m "%s" generic_error_log_message);
    prod_error_message_to_client |> respond ~status:`Internal_server_error

  let caqti_general error =
    match error with
    | #Caqti_error.t as caqti_error ->
        Logs.err (fun m -> m "%s" (Caqti_error.show caqti_error));
        prod_error_message_to_client |> respond ~status:`Internal_server_error
    | _other_error ->
        Logs.err (fun m -> m "%s" generic_error_log_message);
        prod_error_message_to_client |> respond ~status:`Internal_server_error

  let caqti_409_on_duplicate error =
    match error with
    | #Caqti_error.t as caqti_error -> (
        Logs.err (fun m -> m "%s" (Caqti_error.show caqti_error));
        match caqti_error with
        | `Request_failed err ->
            let msg_string = caqti_query_error_message err in
            caqti_error_handle_409_on_duplicate msg_string
        | _ ->
            prod_error_message_to_client
            |> respond ~status:`Internal_server_error )
    | _other_error ->
        Logs.err (fun m -> m "%s" generic_error_log_message);
        prod_error_message_to_client |> respond ~status:`Internal_server_error

  let default = caqti_409_on_duplicate
end

let get_default_error_responder provided_responder =
  Option.value provided_responder ~default:Error_responders.default

module Make = struct
  module Make_response = struct
    module type Make_sig = functor
      (Responses : sig
         type t
       end)
      -> sig
      val f : Responses.t -> Response.t Lwt.t
    end

    module No_content (Responses : Responses.No_content) = struct
      let f () = `String "" |> respond ~status:`No_content
    end

    module Json (Responses : Responses.Json) = struct
      let f content = `Json (content |> Responses.yojson_of_t) |> respond
    end

    module Json_opt (Responses : Responses.Json_opt) = struct
      let f content_opt =
        match content_opt with
        | Some content -> `Json (content |> Responses.yojson_of_t) |> respond
        | None -> `String "" |> respond ~status:`Not_found
    end

    module Json_list (Responses : Responses.Json_list) = struct
      let f content =
        let list_of_json = List.map content ~f:Responses.yojson_of_t in
        let json_of_list = `List list_of_json in
        `Json json_of_list |> respond
    end

    module Json_code (Responses : Responses.Json_code) = struct
      let f content =
        let code_string, content_json =
          match Responses.yojson_of_t content with
          | [%yojson? [ [%y? `String code_string]; [%y? content_json] ]] ->
              (code_string, content_json)
          | _ -> failwith "yo!"
        in
        let status =
          match String.chop_prefix ~prefix:"_" code_string with
          | Some number -> number |> Int.of_string |> Httpaf.Status.of_code
          | None -> failwith "yo!"
        in
        `Json content_json |> respond ~status
    end

    module Created = struct
      module Int (Responses : Responses.Created.Int) (S : Specification.S) =
      struct
        let f id =
          let location = Printf.sprintf "%s/%d" S.path id in
          `String ""
          |> respond
               ~headers:(Httpaf.Headers.of_list [ ("Location", location) ])
               ~status:`Created
      end
    end

    module Empty = struct
      module Code = struct
        module Only (Responses : Responses.Empty.Code) = struct
          let f status = `String "" |> respond ~status
        end

        module Headers (Responses : Responses.Empty.Code.Headers) = struct
          let f (status, headers) =
            `String ""
            |> respond ~headers:(Httpaf.Headers.of_list headers) ~status
        end
      end

      module Bool (Responses : Responses.Empty.Bool) = struct
        let f unit_opt =
          match unit_opt with
          | true -> `String "" |> respond ~status:Responses.success
          | false -> `String "" |> respond ~status:Responses.failure
      end
    end

    module String (Responses : Responses.String) = struct
      let f s = `String s |> respond
    end
  end

  let make_result_response response_f ?error_responder content_result_lwt =
    let error_responder = get_default_error_responder error_responder in
    let%lwt content_result = content_result_lwt in
    let response =
      match content_result with
      | Ok content -> response_f content
      | Error error -> error_responder error
    in
    response

  let make_not_result_response response_f content_lwt =
    let%lwt content = content_lwt in
    response_f content

  module No_content (Responses : Responses.No_content) = struct
    module M = Make_response.No_content (Responses)

    let f ?error_responder content_result_lwt =
      make_result_response M.f ?error_responder content_result_lwt
  end

  module Json (Responses : Responses.Json) = struct
    module M = Make_response.Json (Responses)

    let f ?error_responder content_result_lwt =
      make_result_response M.f ?error_responder content_result_lwt
  end

  module Json_list (Responses : Responses.Json_list) = struct
    module M = Make_response.Json_list (Responses)

    let f ?error_responder content_result_lwt =
      make_result_response M.f ?error_responder content_result_lwt
  end

  module Json_opt (Responses : Responses.Json_opt) = struct
    module M = Make_response.Json_opt (Responses)

    let f ?error_responder content_result_lwt =
      make_result_response M.f ?error_responder content_result_lwt
  end

  module Empty = struct
    module Code = struct
      module Only (Responses : Responses.Empty.Code) = struct
        module M = Make_response.Empty.Code.Only (Responses)

        let f ?error_responder content_result_lwt =
          make_result_response M.f ?error_responder content_result_lwt
      end

      module Headers (Responses : Responses.Empty.Code.Headers) = struct
        module M = Make_response.Empty.Code.Headers (Responses)

        let f ?error_responder content_result_lwt =
          make_result_response M.f ?error_responder content_result_lwt
      end
    end

    module Bool (Responses : Responses.Empty.Bool) = struct
      module M = Make_response.Empty.Bool (Responses)

      let f ?error_responder content_result_lwt =
        make_result_response M.f ?error_responder content_result_lwt
    end
  end

  module Created = struct
    module Int (Responses : Responses.Created.Int) (S : Specification.S) =
    struct
      module M = Make_response.Created.Int (Responses) (S)

      let f ?error_responder content_result_lwt =
        make_result_response M.f ?error_responder content_result_lwt
    end
  end

  module Not_result = struct
    module Json (Responses : Responses.Json) = struct
      module M = Make_response.Json (Responses)

      let f = make_not_result_response M.f
    end

    module Json_code (Responses : Responses.Json_code) = struct
      module M = Make_response.Json_code (Responses)

      let f = make_not_result_response M.f
    end

    module Json_list (Responses : Responses.Json_list) = struct
      module M = Make_response.Json_list (Responses)

      let f = make_not_result_response M.f
    end

    module Json_opt (Responses : Responses.Json_opt) = struct
      module M = Make_response.Json_opt (Responses)

      let f = make_not_result_response M.f
    end

    module Empty_code (Responses : Responses.Empty.Code) = struct
      module M = Make_response.Empty.Code.Only (Responses)

      let f = make_not_result_response M.f
    end

    module Empty_code_headers (Responses : Responses.Empty.Code.Headers) =
    struct
      module M = Make_response.Empty.Code.Headers (Responses)

      let f = make_not_result_response M.f
    end

    module String (Responses : Responses.String) = struct
      module M = Make_response.String (Responses)

      let f = make_not_result_response M.f
    end

    module Created = struct
      module Int (Responses : Responses.Created.Int) (S : Specification.S) =
      struct
        module M = Make_response.Created.Int (Responses) (S)

        let f = make_not_result_response M.f
      end
    end

    module No_content (Responses : Responses.No_content) = struct
      module M = Make_response.No_content (Responses)

      let f = make_not_result_response M.f
    end

    module Empty_opt (Responses : Responses.Empty.Bool) = struct
      module M = Make_response.Empty.Bool (Responses)

      let f = make_not_result_response M.f
    end
  end
end
