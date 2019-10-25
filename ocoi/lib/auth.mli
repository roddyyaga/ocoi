(** Implements authentication/authorization for requests on a per route basis using the [Authorization] HTTP header

    Example use:
    {[let my_route =
        get "/my_route"
          (Ocoi.Auth.Checks.accept_all (fun _ ->
               `String "Hello world!" |> respond'))]}

    implements a very simple kind of "authentication" that accepts all requests to [/my_route].

    A more useful example would replace {!Ocoi.Auth.Checks.accept_all} with some other function with signature
    [auth_credential option -> Request.t -> bool] that takes an [Authorization] head and returns whether it is valid for
    the associated request. For instance, using JWT tokens for authentication:
    {[let jwt_algorithm = Jwt.HS256 "SupaSekretKey"

  let check_user jwt_payload req =
    let jwt_user = Jwt.(find_claim (claim "user_id") jwt_payload) in
    let req_id = param req "id" in
    jwt_user = req_id

  let auth_func =
    let token_check =
      Ocoi.Auth.Checks.jwt ~algorithm:jwt_algorithm ~validate:check_user
    in
    Ocoi.Auth.Checks.bearer_only token_check

  let get_user =
    get "/users/:id"
      (authenticate auth_func (fun _ ->
           get_user (param req "id") |> respond'))]}

*)

open Opium.Std

type auth_credential = [Cohttp.Auth.credential | `Bearer of string]
(** Extends Cohttp authorization header types with Bearer *)

val authenticate :
  check:(auth_credential option -> Request.t -> bool) ->
  (Request.t -> Response.t Lwt.t) ->
  Request.t ->
  Response.t Lwt.t
(** [authenticate ~check handler_body] wraps [handler_body] by using [check] for authentication

    When called on a request, the new function will parse the [Authorization] header of the request and call [check] on
    that and the request. If this gives [true] the original handler body will be called. Otherwise an [empty 401
    Unauthorized] response will be returned. *)

(** Defines various check functions to be used by {!authenticate}. *)
module Checks : sig
  val accept_all : auth_credential option -> Request.t -> bool
  (** Allows all requests *)

  val reject_all : auth_credential option -> Request.t -> bool
  (** Rejects all requests as unauthorized *)

  val bearer_only :
    (string -> Request.t -> bool) ->
    auth_credential option ->
    Request.t ->
    bool
  (** [bearer_only token_check] rejects all requests with an [Authorization] header not of the form [Authorization: Bearer <token>], and uses [token_check] to determine whether requests that are of that form should be allowed *)

  val jwt :
    algorithm:Jwt.algorithm ->
    validate:(Jwt.payload -> Request.t -> bool) ->
    auth_credential option ->
    Request.t ->
    bool
  (** [jwt_check ~algorithm ~validate] produces an auth check that uses JWT tokens

   It rejects requests with a JWT token that cannot be parsed or has an incorrect signature according to [algorithm], and validates other tokens against the request using [validate]. *)
end
