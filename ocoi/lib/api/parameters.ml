open Base
open Opium

module type None = sig
  type t = unit
end

module None = struct
  type t = unit
end

module type Json = sig
  type t

  val t_of_yojson : Yojson.Safe.t -> t
end

module Json = struct
  module type Jwt = sig
    type parameters

    val parameters_of_yojson : Yojson.Safe.t -> parameters

    type t = parameters * Jose.Jwt.payload
  end
end

module Path = struct
  module type One = sig
    type t

    val of_string : string -> t
  end

  module One = struct
    module type Query = sig
      type path

      val query_fields : string list

      val path_of_string : string -> path

      type t = path * string option list
    end

    module type Jwt = sig
      type path

      val of_string : string -> path

      type t = path * Jose.Jwt.payload
    end

    module Int = struct
      type t = int

      let of_string = Int.of_string
    end
  end
end

module type Jwt = sig
  type t = Jose.Jwt.payload
end

module Jwt = struct
  type t = Jose.Jwt.payload
end

module type Custom = sig
  type t

  val f : Request.t -> t
end
