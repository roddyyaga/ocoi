type verb = Get | Post | Put | Delete

let verb_to_string = function
  | Get -> "get"
  | Post -> "post"
  | Put -> "put"
  | Delete -> "delete"

module type S_base = sig
  val verb : verb

  val path : string
end

module type S = sig
  include S_base

  module Parameters : sig
    type t
  end

  module Responses : sig
    type t
  end
end
