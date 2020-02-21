open Base
open Opium.Std
open Ocoi_api

module Make = struct
  module Json (Parameters : Parameters.Json) = struct
    let f req =
      (* TODO catch Yojson.Json_error here (and maybe more?) *)
      let%lwt json = App.json_of_body_exn req in
      match json |> Parameters.t_of_yojson' with
      | Ok x -> x |> Lwt.return
      | Error _ -> failwith "Error parsing JSON"
  end

  module Json_jwt (Parameters : Parameters.Jwt_json) = struct
    let f ~algorithm req =
      let%lwt json = App.json_of_body_exn req in
      let j =
        match json |> Parameters.parameters_of_yojson' with
        | Ok x -> x
        | Error _ -> failwith "Error decoding JSON"
      in
      let jwt =
        let token_opt = Auth.get_token req in
        let open Option in
        match
          token_opt >>| fun token ->
          Jwt_utils.verify_and_decode ~algorithm token
        with
        | Some (Payload p) -> p
        | Some SignatureMismatch -> failwith "Signature mismatch"
        | Some FormatError -> failwith "Format error"
        | None -> failwith "No JWT token"
      in
      (j, jwt) |> Lwt.return
  end

  module Jwt (Parameters : Parameters.Jwt) = struct
    let f ~algorithm req =
      let jwt =
        let token_opt = Auth.get_token req in
        let open Option in
        match
          token_opt >>| fun token ->
          Jwt_utils.verify_and_decode ~algorithm token
        with
        | Some (Payload p) -> p
        | Some SignatureMismatch -> failwith "Signature mismatch"
        | Some FormatError -> failwith "Format error"
        | None -> failwith "No JWT token"
      in
      jwt |> Lwt.return
  end

  module None (Parameters : Parameters.None) = struct
    let f _req = () |> Lwt.return
  end

  module Path = struct
    let get_one_param_name (module S : Specification.S) =
      let () = assert (String.count ~f:(Char.( = ) ':') S.path = 1) in

      let name =
        (* Find the only occurrence of [:some_var] in the path *)
        let pattern = Str.regexp {re|.*:\([^/]*\)\(/\|$\)|re} in
        let () = assert (Str.string_match pattern S.path 0) in
        Str.matched_group 1 S.path
      in
      name

    module One (Parameters : Parameters.Path.One) (S : Specification.S) = struct
      let name = get_one_param_name (module S)

      let f req = Parameters.of_string (param req name) |> Lwt.return
    end

    module One_and = struct
      module Query
          (Parameters : Parameters.Path.One_and.Query)
          (S : Specification.S) =
      struct
        let name = get_one_param_name (module S)

        let f req =
          let path_parameter_value =
            Parameters.path_of_string (param req name)
          in
          let query_parameter_values =
            List.map
              ~f:(Uri.get_query_param (Request.uri req))
              Parameters.query_fields
          in
          (path_parameter_value, query_parameter_values) |> Lwt.return
      end
    end
  end

  module Custom (Parameters : Parameters.Custom) = struct
    let f req = Parameters.f req |> Lwt.return
  end
end
