open Api.Specification

module Make = struct
  module Parameters = Parameters.Make
  module Responses = Responses.Make
end

let handler (module S : Api.Specification.S) input_f impl_f output_f =
  let route = verb_to_route S.verb in
  let handler req =
    let%lwt impl_input = req |> input_f in
    impl_input |> impl_f |> output_f
  in
  route S.path handler

module type Crud = sig
  module Api : sig
    module Create : sig
      val verb : verb

      val path : string

      module Parameters : Api.Parameters.Json

      module Responses : Api.Responses.Created.Int
    end

    module Index : sig
      val verb : verb

      val path : string

      module Parameters : Api.Parameters.None

      module Responses : Api.Responses.Json_list
    end

    module Show : sig
      val verb : verb

      val path : string

      module Parameters : Api.Parameters.One_param with type t = int

      module Responses : Api.Responses.Json_opt
    end

    module Update : sig
      val verb : verb

      val path : string

      module Parameters : Api.Parameters.Json

      module Responses : Api.Responses.No_content
    end

    module Destroy : sig
      val verb : verb

      val path : string

      module Parameters : Api.Parameters.One_param with type t = int

      module Responses : Api.Responses.No_content
    end
  end

  module Controller : sig
    val create :
      Api.Create.Parameters.t ->
      (int, [> Caqti_error.call_or_retrieve ]) result Lwt.t

    val index :
      unit ->
      (Api.Index.Responses.t list, [> Caqti_error.call_or_retrieve ]) result
      Lwt.t

    val show :
      int ->
      (Api.Show.Responses.t option, [> Caqti_error.call_or_retrieve ]) result
      Lwt.t

    val update :
      Api.Update.Parameters.t ->
      (unit, [> Caqti_error.call_or_retrieve ]) result Lwt.t

    val destroy : int -> (unit, [> Caqti_error.call_or_retrieve ]) result Lwt.t
  end
end

let crud (module Crud : Crud) =
  let open Crud.Api in
  let open Crud.Controller in
  let create =
    let module P = Make.Parameters.Json (Create.Parameters) in
    let module R = Make.Responses.Created.Int (Create.Responses) (Create) in
    handler (module Create) P.f create R.f
  in
  let index =
    let module P = Make.Parameters.None (Index.Parameters) in
    let module R = Make.Responses.Json_list (Index.Responses) in
    handler (module Index) P.f index R.f
  in
  let show =
    let module P = Make.Parameters.One_param (Show.Parameters) (Show) in
    let module R = Make.Responses.Json_opt (Show.Responses) in
    handler (module Show) P.f show R.f
  in
  let update =
    let module P = Make.Parameters.Json (Update.Parameters) in
    let module R = Make.Responses.No_content (Update.Responses) in
    handler (module Update) P.f update R.f
  in
  let destroy =
    let module P = Make.Parameters.One_param (Destroy.Parameters) (Destroy) in
    let module R = Make.Responses.No_content (Destroy.Responses) in
    handler (module Destroy) P.f destroy R.f
  in
  [ create; index; show; update; destroy ]
