(** Contains module types for defining parameters of API endpoints, and modules that implement these types when relevant *)

(** For endpoints that take no parameters *)
module type None = sig
  type t = unit
end

(** Implementation of {!modtype:None} *)
module None : sig
  type t = unit
end

(** For endpoints that take a piece of JSON *)
module type Json = sig
  type t

  val t_of_yojson : Yojson.Safe.t -> t
end

(** For endpoints that take a piece of JSON and some other data *)
module Json : sig
  (** For endpoints that take a piece of JSON and a JWT token *)
  module type Jwt = sig
    type parameters

    val parameters_of_yojson : Yojson.Safe.t -> parameters

    type t = parameters * Jose.Jwt.payload
  end
end

(** For endpoints with parameters in the path of the URL, for example [id] in [example.com/things/:id], that don't take JSON (for those that do, see {!modtype:Json.Path}). *)
module Path : sig
  (** For endpoints where the only parameter is a single path parameter.
      Multiple path parameters will be implemented in the future. *)
  module type One = sig
    type t

    val of_string : string -> t
  end

  (** For endpoints with a single path parameter and some other non-path parameters *)
  module One : sig
    (** For endpoints with a single path parameter and some query parameters *)
    module type Query = sig
      type path

      val query_fields : string list

      val path_of_string : string -> path

      type t = path * string option list
    end

    (** For endpoints with a single path parameter and a JWT *)
    module type Jwt = sig
      type path

      val of_string : string -> path

      type t = path * Jose.Jwt.payload
    end

    (** For endpoints with a single integer path parameter *)
    module Int : sig
      type t = int

      val of_string : string -> t
    end
  end
end

(** For endpoints which only take a JWT *)
module type Jwt = sig
  type t = Jose.Jwt.payload
end

module Jwt : Jwt
(** Implementation of {!modtype:Jwt} *)

(** For custom parameter specifications that supply some function [f] for producing the parameter type from an Opium request. *)
module type Custom = sig
  type t

  val f : Opium.Request.t -> t
end
