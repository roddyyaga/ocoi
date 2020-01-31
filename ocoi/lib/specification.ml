open Opium.Std

type verb = Get | Post | Put | Delete

let verb_to_route verb =
  match verb with Get -> get | Post -> post | Put -> put | Delete -> delete

module type S = sig
  val verb : verb

  val path : string

  module Parameters : sig
    type t
  end

  module Responses : sig
    type t
  end
end

module type Implementation = sig
  type pt

  type rt

  val f : pt -> rt Lwt.t
end
