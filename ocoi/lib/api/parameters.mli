(** Contains module types for defining parameters of API endpoints, and modules that implement these types when relevant *)

(** For endpoints that take a piece of JSON *)
module type Json = sig
  type t

  val t_of_yojson' : Yojson.Safe.t -> t Ppx_yojson_conv_lib.Yojson_conv.Result.t
end

(** For endpoints that take a piece of JSON and a JWT token *)
module type Jwt_json = sig
  type parameters

  val parameters_of_yojson' :
    Yojson.Safe.t -> parameters Ppx_yojson_conv_lib.Yojson_conv.Result.t

  type t = parameters * Jwt.payload
end

(** For endpoints that take no parameters *)
module type None = sig
  type t = unit
end

module None : sig
  type t = unit
end

(** For endpoints with a single parameter in the path of the URL, for example [id] in [example.com/things/:id]

    {b Not} for endpoints with a single query parameters (query parameters are not yet implemented).
    The general case of multiple path parameters is also not yet implemented, but will be. *)
module type One_param = sig
  type t

  val of_string : string -> t
end

(** Contains implementations of {!module-type:One_param} for common types *)
module One_param : sig
  (** For integer parameters *)
  module Int : sig
    type t = int

    val of_string : string -> t
  end

  (** For string parameters *)
  module String : sig
    type t = string

    val of_string : string -> t
  end
end

(** For custom parameter specifications that supply some function [f] for producing the parameter type from an Opium request *)
module type Custom = sig
  type t

  val f : Opium.Std.Request.t -> t
end
