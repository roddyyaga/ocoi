open Base

type status_code = Cohttp.Code.status_code

module Implementations = struct
  module type Unit = sig
    type t = unit
  end

  module Unit = struct
    type t = unit
  end

  module type Int = sig
    type t = int
  end

  module Int = struct
    type t = int
  end
end

module type Json = sig
  type t

  val yojson_of_t : t -> Yojson.Safe.t
end

module type No_content = Implementations.Unit

module No_content = Implementations.Unit

module Created = struct
  module type Int = Implementations.Int

  module Int = Implementations.Int
end

module type Empty_code = sig
  type t = status_code
end

module Empty_code = struct
  type t = status_code
end

module type Empty_code_headers = sig
  type t = status_code * (string * string) list
end

module Empty_code_headers = struct
  type t = status_code * (string * string) list
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

module type Raw_json = sig
  type t = Yojson.t
end

module Raw_json = struct
  type t = Yojson.t
end
