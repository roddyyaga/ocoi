open Base
open Opium.Std

module type Jwt_json = sig
  type parameters

  val parameters_of_yojson' :
    Yojson.Safe.t -> parameters Ppx_yojson_conv_lib.Yojson_conv.Result.t

  type t = parameters * Jwt.payload
end

module type Json = sig
  type t

  val t_of_yojson' : Yojson.Safe.t -> t Ppx_yojson_conv_lib.Yojson_conv.Result.t
end

module type None = sig
  type t = unit
end

module None = struct
  type t = unit
end

module Path = struct
  module type One = sig
    type t

    val of_string : string -> t
  end

  module One = struct
    module Int = struct
      type t = int

      let of_string = Int.of_string
    end

    module String = struct
      type t = string

      let of_string = Fn.id
    end
  end

  module One_and = struct
    module type Query = sig
      type path

      val query_fields : string list

      val path_of_string : string -> path

      type t = path * string option list
    end
  end
end

module type Custom = sig
  type t

  val f : Request.t -> t
end

module Json_list (Json : Json) = Json
