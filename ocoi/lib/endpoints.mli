type verb = Get | Post | Put | Delete

val verb_to_route : verb -> Opium.App.route

module type Specification = sig
  val verb : verb

  val path : string

  module Parameters : sig
    type t
  end

  module Responses : sig
    type t
  end
end

module type Endpoint = sig
  module Specification : Specification

  module Implementation : sig
    val f : Specification.Parameters.t -> Specification.Responses.t Lwt.t
  end
end

module Parameters : sig
  module type Jwt_json = sig
    type parameters

    val parameters_of_yojson :
      Yojson.Safe.t -> parameters Ppx_deriving_yojson_runtime.error_or

    type t = parameters * Jwt.payload
  end

  module type Json = sig
    type t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
  end
end

module Responses : sig
  module type Json = sig
    type t

    val to_yojson : t -> Yojson.Safe.t
  end
end

module type Json_to_json = sig
  module Specification : sig
    val verb : verb

    val path : string

    module Parameters : Parameters.Json

    module Responses : Responses.Json
  end

  module Implementation : sig
    val f : Specification.Parameters.t -> Specification.Responses.t Lwt.t
  end
end

module type Json_jwt_to_json = sig
  module Specification : sig
    val verb : verb

    val path : string

    module Parameters : Parameters.Jwt_json

    module Responses : Responses.Json
  end

  module Implementation : sig
    val f : Specification.Parameters.t -> Specification.Responses.t Lwt.t
  end
end

module Register : sig
  val json_to_json : (module Json_to_json) -> Opium.App.builder

  val json_jwt_to_json :
    (module Json_jwt_to_json) -> algorithm:Jwt.algorithm -> Opium.App.builder
end
