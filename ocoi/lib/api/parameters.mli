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

(** For endpoints parameters in the path of the URL, for example [id] in [example.com/things/:id] *)
module Path : sig
  (** For endpoints where the only parameter is a single path parameter.
      Multiple path parameters will be implemented in the future. *)
  module type One = sig
    type t

    val of_string : string -> t
  end

  (** Contains implementations of {!module-type:One} for common types *)
  module One : sig
    (** For integer parameters *)
    module Int : sig
      type t = int

      val of_string : string -> t
    end

    (** For string parameters *)
    module String : sig
      type t = string

      val of_string : 'a -> 'a
    end
  end

  (** For endpoints with a single path parameter and some other non-path parameters *)
  module One_and : sig
    (** For endpoints with a single path parameter and some query parameters *)
    module type Query = sig
      type path

      val query_fields : string list

      val path_of_string : string -> path

      type t = path * string option list
    end
  end
end

module type Jwt_path_one = sig
  type parameters

  val of_string : string -> parameters

  type t = parameters * Jwt.payload
end

module Jwt_path_one_int : sig
  type parameters = int

  val of_string : string -> parameters

  type t = parameters * Jwt.payload
end

(** For custom parameter specifications that supply some function [f] for producing the parameter type from an Opium request *)
module type Custom = sig
  type t

  val f : Opium.Std.Request.t -> t
end

module type Jwt = sig
  type t = Jwt.payload
end

module Jwt : Jwt
