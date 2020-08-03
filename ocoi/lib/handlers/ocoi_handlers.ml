open Ocoi_api.Specification

module Make = struct
  module Parameters = Parameters.Make
  module Responses = Responses.Make
end

module Error_responders = Error_responders
module Utils = Utils

let handler ?(error_responder = Error_responders.default)
    (module S : Ocoi_api.Specification.S) input_f impl_f output_f =
  let route = verb_to_route S.verb in
  let handler req =
    try
      let open Lwt_result in
      let%lwt impl_output = req |> input_f >>= fun x -> x |> impl_f in
      match impl_output with Ok y -> output_f y | Error e -> error_responder e
    with e ->
      let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
      Logs.err (fun m -> m "Uncaught exception: %s\n%s" msg stack);
      Error_responders.respond_error ()
  in
  route S.path handler

type caqti_error =
  [ `Connect_failed of Caqti_error.connection_error
  | `Connect_rejected of Caqti_error.connection_error
  | `Decode_rejected of Caqti_error.coding_error
  | `Encode_failed of Caqti_error.coding_error
  | `Encode_rejected of Caqti_error.coding_error
  | `Post_connect of Caqti_error.call_or_retrieve
  | `Request_failed of Caqti_error.query_error
  | `Request_rejected of Caqti_error.query_error
  | `Response_failed of Caqti_error.query_error
  | `Response_rejected of Caqti_error.query_error ]

module type Crud = sig
  module Api : sig
    module Create : sig
      val verb : verb

      val path : string

      module Parameters : Ocoi_api.Parameters.Json

      module Responses : Ocoi_api.Responses.Created.Int
    end

    module Index : sig
      val verb : verb

      val path : string

      module Parameters : Ocoi_api.Parameters.None

      module Responses : Ocoi_api.Responses.Json_list
    end

    module Show : sig
      val verb : verb

      val path : string

      module Parameters : Ocoi_api.Parameters.Path.One with type t = int

      module Responses : Ocoi_api.Responses.Json_opt
    end

    module Update : sig
      val verb : verb

      val path : string

      module Parameters : Ocoi_api.Parameters.Json

      module Responses : Ocoi_api.Responses.No_content
    end

    module Destroy : sig
      val verb : verb

      val path : string

      module Parameters : Ocoi_api.Parameters.Path.One with type t = int

      module Responses : Ocoi_api.Responses.No_content
    end
  end

  module Controller : sig
    val create : Api.Create.Parameters.t -> (int, [> caqti_error ]) result Lwt.t

    val index :
      unit -> (Api.Index.Responses.t list, [> caqti_error ]) result Lwt.t

    val show :
      int -> (Api.Show.Responses.t option, [> caqti_error ]) result Lwt.t

    val update :
      Api.Update.Parameters.t -> (unit, [> caqti_error ]) result Lwt.t

    val destroy : int -> (unit, [> caqti_error ]) result Lwt.t
  end
end

let crud (module Crud : Crud) =
  let open Crud.Api in
  let open Crud.Controller in
  let create =
    let module P = Make.Parameters.Json.Only (Create.Parameters) in
    let module R = Make.Responses.Created.Int (Create.Responses) (Create) in
    handler (module Create) P.f create R.f
  in
  let index =
    let module P = Make.Parameters.None (Index.Parameters) in
    let module R = Make.Responses.Json_list (Index.Responses) in
    handler (module Index) P.f index R.f
  in
  let show =
    let module P = Make.Parameters.Path.One.Only (Show.Parameters) (Show) in
    let module R = Make.Responses.Json_opt (Show.Responses) in
    handler (module Show) P.f show R.f
  in
  let update =
    let module P = Make.Parameters.Json.Only (Update.Parameters) in
    let module R = Make.Responses.No_content (Update.Responses) in
    handler (module Update) P.f update R.f
  in
  let destroy =
    let module P = Make.Parameters.Path.One.Only (Destroy.Parameters) (Destroy)
    in
    let module R = Make.Responses.No_content (Destroy.Responses) in
    handler (module Destroy) P.f destroy R.f
  in
  [ create; index; show; update; destroy ]

module Auth = Auth
module Jwt_utils = Jwt_utils
