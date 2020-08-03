open Base
open Ocoi_api
open Utils

let get_default_error_responder provided_responder =
  Option.value provided_responder ~default:Error_responders.default

module Make = struct
  module No_content (Responses : Responses.No_content) = struct
    let f () = `String "" |> respond ~status:`No_content
  end

  module Json (Responses : Responses.Json) = struct
    let f content = `Json (content |> Responses.yojson_of_t) |> respond
  end

  module Json_opt (Responses : Responses.Json_opt) = struct
    let f ?(status = `Not_found) content_opt =
      match content_opt with
      | Some content -> `Json (content |> Responses.yojson_of_t) |> respond
      | None -> `String "" |> respond ~status
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
