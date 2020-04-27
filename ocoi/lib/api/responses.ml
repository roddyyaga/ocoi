open Base

type status_code = Cohttp.Code.status_code

module type No_content = sig
  type t = unit
end

module No_content = Unit

module type Json = sig
  type t

  val yojson_of_t : t -> Yojson.Safe.t
end

module Created = struct
  module type Int = sig
    type t = int
  end

  module Int = Int
end

module Empty = struct
  (* TODO - reorganise Empty_codes *)
  module type Code = sig
    type t = status_code
  end

  module Code = struct
    module Only = struct
      type t = status_code
    end

    module type Headers = sig
      type t = status_code * (string * string) list
    end

    module Headers = struct
      type t = status_code * (string * string) list
    end
  end

  (** For endpoints that return an empty response with one of two status codes indicating success or failure. *)
  module type Bool = sig
    val success : status_code

    val failure : status_code

    type t = bool
  end
end

module type String = sig
  type t = string
end

module String = struct
  type t = string
end

module type Json_list = Json

module type Json_opt = Json

module type Json_code = Json

(* TODO - see if we can make using these mandatory *)
module Json_list (Json : Json) = Json
module Json_opt (Json : Json) = Json
module Json_code (Json : Json) = Json

module Raw_json = struct
  type t = Yojson.Safe.t

  let yojson_of_t = Fn.id
end
