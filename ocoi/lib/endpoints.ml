open Core
open Opium.Std

type verb = Get | Post | Put | Delete

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
end

module Responses = struct
  module type Json = sig
    type t

    val to_yojson : t -> Yojson.Safe.t
  end
end

module Make_in = struct
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
end

module Make_out = struct
  module Json (Responses : Responses.Json) = struct
    let f response_lwt =
      let%lwt response = response_lwt in
      `Json (response |> Responses.to_yojson) |> respond'
  end

  module Json_with_code (Responses : Responses.Json) = struct
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
end

module type Json_to_json = sig
  module Specification : sig
    val verb : verb

    val path : string

    module Parameters : Parameters.Json

    module Responses : Responses.Json
  end

  module Implementation : sig
    val f : Specification.Parameters.t -> Specification.Responses.t Lwt.t
  end
end

module type Json_jwt_to_json = sig
  module Specification : sig
    val verb : verb

    val path : string

    module Parameters : Parameters.Jwt_json

    module Responses : Responses.Json
  end

  module Implementation : sig
    val f : Specification.Parameters.t -> Specification.Responses.t Lwt.t
  end
end

let register input_f impl_f output_f (module Endpoint : Endpoint) =
  let route = verb_to_route Endpoint.Specification.verb in
  let handler req =
    let%lwt impl_input = req |> input_f in
    impl_input |> impl_f |> output_f
  in
  route Endpoint.Specification.path handler

module Register = struct
  let json_to_json (module Endpoint : Json_to_json) =
    let module Input = Make_in.Json (Endpoint.Specification.Parameters) in
    let module Output = Make_out.Json (Endpoint.Specification.Responses) in
    register Input.f Endpoint.Implementation.f Output.f (module Endpoint)

  let json_jwt_to_json (module Endpoint : Json_jwt_to_json) ~algorithm =
    let module Input = Make_in.Json_jwt (Endpoint.Specification.Parameters) in
    let module Output = Make_out.Json (Endpoint.Specification.Responses) in
    register (Input.f ~algorithm) Endpoint.Implementation.f Output.f
      (module Endpoint)
end

module Example = struct
  module Specification = struct
    let verb = Get

    let path = "/example"

    module Parameters = struct
      type t = { teachers_name: string; childhood_pet: string }
      [@@deriving yojson]
    end

    module Responses = struct
      type t = { id: int; stripper_name: string } [@@deriving yojson]
    end
  end

  module Implementation = struct
    open Specification.Parameters
    open Specification.Responses

    let f { teachers_name; childhood_pet } =
      { id = 1; stripper_name = teachers_name ^ childhood_pet } |> Lwt.return
  end
end

module Example2 = struct
  module Specification = struct
    let verb = Get

    let path = "/example"

    module Parameters = struct
      type t = { teachers_name: string; childhood_pet: string }
      [@@deriving yojson]
    end

    module Responses = struct
      type ok = { id: int; stripper_name: string } [@@deriving yojson]

      type error = { message: string } [@@deriving yojson]

      type t = [ `_200 of ok | `_500 of error ] [@@deriving yojson]
    end
  end

  module Implementation = struct
    open Specification.Parameters
    open Specification.Responses

    let f { teachers_name; childhood_pet } =
      match teachers_name with
      | "cool" ->
          `_200 { id = 1; stripper_name = teachers_name ^ childhood_pet }
          |> Lwt.return
      | _ -> `_500 { message = "uncool teachers name!" } |> Lwt.return
  end
end

module Example3 = struct
  module Specification = struct
    let verb = Post

    let path = "/example3"

    module Parameters = struct
      type parameters = { teachers_name: string; childhood_pet: string }
      [@@deriving yojson]

      type t = parameters * Jwt.payload end

    module Responses = struct
      type ok = { id: int; friend_name: string } [@@deriving yojson]

      type error = { message: string } [@@deriving yojson]

      type t = [ `_200 of ok | `_500 of error ] [@@deriving yojson]
    end
  end

  module Implementation = struct
    open Specification.Parameters
    open Specification.Responses

    let f ({ teachers_name; childhood_pet }, payload) =
      match
        Option.mem
          (Jwt_utils.get_claim "sub" payload)
          teachers_name ~equal:String.( = )
      with
      | true -> (
          match teachers_name with
          | "cool" ->
              `_200 { id = 1; friend_name = teachers_name ^ childhood_pet }
              |> Lwt.return
          | _ -> `_500 { message = "uncool teachers name!" } |> Lwt.return )
      | false -> `_500 { message = "permission denied!" } |> Lwt.return
  end
end

let _ =
  Register.json_to_json
    ( module struct
      module Specification = Example.Specification
      module Implementation = Example.Implementation
    end )

let _ = Register.json_to_json (module Example2)

let _ = Register.json_jwt_to_json (module Example3)
