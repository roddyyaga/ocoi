module type None = sig
  type t = unit
end

module None = struct
  type t = unit
end

module type Json = sig
  type t

  val yojson_of_t : t -> Yojson.Safe.t
end

module Path = struct
  module type One = sig
    type t

    val to_string : t -> string
  end

  module One = struct
    module Int = struct
      type t = int

      let to_string = string_of_int
    end
  end
end
