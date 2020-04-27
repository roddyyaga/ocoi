(** Contains module types for defining responses of API endpoints, and modules that implement these types when relevant.

    For more details, see {!Ocoi_handlers__.Responses.Make}.*)

open Base

type status_code = Cohttp.Code.status_code
(** Represents an HTTP status code *)

(** For endpoints that return an empty response with a [204 No content] code *)
module type No_content = sig
  type t = unit
end

module No_content : No_content

(** For endpoints that return a piece of JSON *)
module type Json = sig
  type t

  val yojson_of_t : t -> Yojson.Safe.t
end

module type Json_list = Json
(** {!module-type:Json_list}, {!module-type:Json_opt} and {!module-type:Json_code} are aliases for {!module-type:Json},
 * and the functors with these names don't do anything. But they should still be used for endpoints will be used with
 * {!Ocoi_handlers__.Responses.Make.Json_list} and similar for documentation purposes and to enable (currently hypothetical) *)

module type Json_opt = Json

module type Json_code = Json

module Json_list (Some_json : Json) : Json with type t = Some_json.t

module Json_opt (Some_json : Json) : Json with type t = Some_json.t

module Json_code (Some_json : Json) : Json with type t = Some_json.t

(* For endpoints with implementations that return a piece of JSON directly ({!module-type:Json} is for endpoints with implementations that return something such as a record that can be encoded as JSON) *)
module Raw_json : Json

(** For endpoints that return an empty response and a [Location] header with a URL with a single path parameter *)
module Created : sig
  module type Int = sig
    type t = int
  end

  module Int : Int
end

module Empty : sig
  (** For endpoints that return an empty response with a certain status code *)
  module type Code = sig
    type t = status_code
  end

  module Code : sig
    module Only : Code

    (** For endpoints that return an empty response with a certain status code and set of headers *)
    module type Headers = sig
      type t = status_code * (string * string) sexp_list
    end

    module Headers : Headers
  end

  (** For endpoints that return an empty response with one of two status codes indicating success or failure. *)
  module type Bool = sig
    val success : status_code

    val failure : status_code

    type t = bool
  end
end

(* For endpoints that return a string *)
module type String = sig
  type t = string
end

module String : String
