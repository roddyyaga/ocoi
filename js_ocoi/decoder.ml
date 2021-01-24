open Lwt.Infix
module Fetch = Ezjs_fetch_lwt

module Make = struct
  module Created = struct
    module Int (R : Responses.Created.Int) = struct
      type error = [ `Wrong_code of string Fetch.response | `No_location ]

      let f response_lwt =
        response_lwt >|= fun response ->
        match response with
        | Ok (response : string Fetch.response) -> (
            match response.status with
            | 201 -> (
                match List.assoc_opt "Location" response.headers with
                | Some location ->
                    let parts = String.split_on_char '/' location in
                    Ok (int_of_string (Utils.list_last parts))
                | None -> Error `No_location )
            | _ -> Error (`Wrong_code response) )
        | Error err -> Error (`Fetch_error err)
    end
  end
end

module No_content (R : Responses.No_content) = struct
  let f response_lwt =
    response_lwt >|= fun response ->
    match response with
    | Ok (response : string Fetch.response) -> (
        match response.status with
        | 204 -> Ok ()
        | _ -> Error (`Wrong_code response) )
    | Error err -> Error (`Fetch_error err)
end

module Json (R : Responses.Json) = struct
  let f response_lwt =
    response_lwt >|= fun response ->
    match response with
    | Ok (response : string Fetch.response) -> (
        match response.status with
        | 200 -> Ok (R.t_of_yojson (Yojson.Safe.from_string response.body))
        | _ -> Error (`Wrong_code response) )
    | Error err -> Error (`Fetch_error err)
end

module Json_list (R : Responses.Json_list) = struct
  let f response_lwt =
    response_lwt >|= fun response ->
    match response with
    | Ok (response : string Fetch.response) -> (
        match response.status with
        | 200 ->
            Ok
              ( response.body |> Yojson.Safe.from_string
              |> Yojson.Safe.Util.to_list |> List.map R.t_of_yojson )
        | _ -> Error (`Wrong_code response) )
    | Error err -> Error (`Fetch_error err)
end

module Json_opt (R : Responses.Json_list) = struct
  let f response_lwt =
    response_lwt >|= fun response ->
    match response with
    | Ok (response : string Fetch.response) -> (
        match response.status with
        | 200 ->
            Ok
              ( response.body |> Yojson.Safe.from_string |> R.t_of_yojson
              |> Option.some )
        | 404 -> Ok None
        | _ -> Error (`Wrong_code response) )
    | Error err -> Error (`Fetch_error err)
end
