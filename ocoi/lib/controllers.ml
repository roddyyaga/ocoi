open Core
open Opium.Std
open Handler_utils

module type Rud = sig
  type t
  (** The model type *)

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val index : unit -> t list Lwt.t
  (** Gets all instances of the model *)

  val show : int -> t option Lwt.t
  (** Gets an instance of the model by id *)

  (* TODO - add create? *)

  val update : t -> unit Lwt.t
  (** Update a model *)

  val destroy : int -> unit Lwt.t
  (** Destroy a model *)
end

let index_handler name (module Rud : Rud) =
  get name (fun _ ->
      let%lwt resources = Rud.index () in
      let resources_json = List.map resources ~f:Rud.to_yojson in
      `Json (`List resources_json) |> respond')

let show_handler name (module Rud : Rud) =
  get (id_path name) (fun req ->
      let%lwt resource_opt = Rud.show (int_of_string (param req "id")) in
      match resource_opt with
      | Some resource -> `Json (resource |> Rud.to_yojson) |> respond'
      | None -> `String "" |> respond' ~code:`Not_found)

let update_handler name (module Rud : Rud) =
  put name (fun req ->
      let%lwt json = App.json_of_body_exn req in
      let resource_err = Rud.of_yojson json in
      match resource_err with
      | Ok resource ->
          let%lwt () = Rud.update resource in
          empty_response `No_content
      (* TODO - make error message nicer *)
      | Error err ->
          respond_bad_request_400 ("(At least one) bad field: " ^ err))

let destroy_handler name (module Rud : Rud) =
  delete (id_path name) (fun req ->
      let%lwt () = Rud.destroy (int_of_string (param req "id")) in
      empty_response `No_content)

let register_rud name (module Rud : Rud) app =
  app
  |> show_handler name (module Rud)
  |> update_handler name (module Rud)
  |> destroy_handler name (module Rud)
  |> index_handler name (module Rud)
