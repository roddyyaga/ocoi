module Created = struct
  module type Int = sig
    type t = int
  end

  module Int = struct
    type t = int
  end
end

module type No_content = sig
  type t = unit
end

module No_content = struct
  type t = unit
end

module type Json = sig
  type t

  val t_of_yojson : Yojson.Safe.t -> t
end

module type Json_list = Json

module type Json_opt = Json
