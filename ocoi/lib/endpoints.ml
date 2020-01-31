open Core
open Opium.Std

type verb = Get | Post | Put | Delete

type status_code = Cohttp.Code.status_code

let verb_to_route verb =
  match verb with Get -> get | Post -> post | Put -> put | Delete -> delete

module type Specification = sig
  val verb : verb

  val path : string

  module Parameters : sig
    type t
  end

  module Responses : sig
    type t
  end
end

module type Implementation = sig
  type pt

  type rt

  val f : pt -> rt Lwt.t
end

module type Endpoint = sig
  module Specification : Specification

  module Implementation : sig
    val f : Specification.Parameters.t -> Specification.Responses.t Lwt.t
  end
end

module Parameters = struct
  module type Jwt_json = sig
    type parameters

    val parameters_of_yojson :
      Yojson.Safe.t -> parameters Ppx_deriving_yojson_runtime.error_or

    type t = parameters * Jwt.payload
  end

  module type Json = sig
    type t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
  end

  module type None = sig
    type t = unit
  end

  module None = struct
    type t = unit
  end

  module type One_param = sig
    type t

    val of_string : string -> t
  end

  module One_param = struct
    module Int = struct
      type t = int

      let of_string = int_of_string
    end

    module String = struct
      type t = string

      let of_string = Fn.id
    end
  end

  module type Custom = sig
    type t

    val f : Request.t -> t
  end

  module Json_list (Json : Json) = Json
end

module Responses = struct
  module type Json = sig
    type t

    val to_yojson : t -> Yojson.Safe.t
  end

  module type Empty_code_headers = sig
    type t = status_code * (string * string) list
  end

  module Empty_code_headers = struct
    type t = status_code * (string * string) list
  end

  module Json_list (Json : Json) = Json
end

module Make = struct
  module Parameters = struct
    module Json (Parameters : Parameters.Json) = struct
      let f req =
        (* TODO catch Yojson.Json_error here (and maybe more?) *)
        let%lwt json = App.json_of_body_exn req in
        let j =
          match json |> Parameters.of_yojson with
          | Ok x -> x
          | Error _ -> failwith "erro"
        in
        j |> Lwt.return
    end

    module Json_jwt (Parameters : Parameters.Jwt_json) = struct
      let f ~algorithm req =
        let%lwt json = App.json_of_body_exn req in
        let j =
          match json |> Parameters.parameters_of_yojson with
          | Ok x -> x
          | Error _ -> failwith "erro"
        in
        let jwt =
          let token_opt = Auth.get_token req in
          let open Option in
          match
            token_opt >>| fun token ->
            Jwt_utils.verify_and_decode ~algorithm token
          with
          | Some (Payload p) -> p
          | _ -> failwith "jwt err"
        in
        (j, jwt) |> Lwt.return
    end

    module None (Parameters : Parameters.None) = struct
      let f _req = () |> Lwt.return
    end

    module One_param (Parameters : Parameters.One_param) (S : Specification) =
    struct
      let () = assert (String.count ~f:(( = ) ':') S.path = 1)

      let name =
        let pattern = Str.regexp {re|.*:\([^/]*\)\(/\|$\)|re} in
        let () = assert (Str.string_match pattern S.path 0) in
        Str.matched_group 1 S.path

      let f req = Parameters.of_string (param req name) |> Lwt.return
    end

    module Custom (Parameters : Parameters.Custom) = struct
      let f req = Parameters.f req |> Lwt.return
    end
  end

  module Responses = struct
    module Json (Responses : Responses.Json) = struct
      let f response_lwt =
        let%lwt response = response_lwt in
        `Json (response |> Responses.to_yojson) |> respond'
    end

    module Json_code (Responses : Responses.Json) = struct
      let f response_lwt =
        let%lwt response = response_lwt in
        let code_string, content_json =
          match Responses.to_yojson response with
          | [%yojson? [ [%y? `String code_string]; [%y? content_json] ]] ->
              (code_string, content_json)
          | _ -> failwith "yo!"
        in
        let code =
          match String.chop_prefix ~prefix:"_" code_string with
          | Some number -> number |> int_of_string |> Cohttp.Code.status_of_code
          | None -> failwith "yo!"
        in
        `Json content_json |> respond' ~code
    end

    module Json_list (Responses : Responses.Json) = struct
      let f response_lwt =
        let%lwt response = response_lwt in
        let list_of_json = List.map response ~f:Responses.to_yojson in
        let json_of_list = `List list_of_json in
        `Json json_of_list |> respond'
    end

    module Empty_code_headers (Responses : Responses.Empty_code_headers) =
    struct
      let f response_lwt =
        let%lwt code, headers = response_lwt in
        `String "" |> respond' ~headers:(Cohttp.Header.of_list headers) ~code
    end
  end
end

let handler (module S : Specification) input_f impl_f output_f =
  let route = verb_to_route S.verb in
  let handler req =
    let%lwt impl_input = req |> input_f in
    impl_input |> impl_f |> output_f
  in
  route S.path handler

module type Some_P = sig
  type t

  val f : Request.t -> t Lwt.t
end

module type Some_R = sig
  type t

  val f : t Lwt.t -> Response.t Lwt.t
end

module Handler
    (S : Specification)
    (P : Some_P with type t := S.Parameters.t)
    (R : Some_R with type t := S.Responses.t)
    (I : Implementation
           with type pt := S.Parameters.t
            and type rt := S.Responses.t) =
struct
  let f = handler (module S) P.f I.f R.f
end
