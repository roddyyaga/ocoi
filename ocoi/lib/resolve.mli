open Core
open Opium.Std

val resolve :
  ('a -> Opium.App.body) ->
  ('b, 'a) result Lwt.t ->
  ('b -> Opium.App.body) ->
  Response.t Lwt.t

val string_id :
  ('a, string) result Lwt.t -> ('a -> Opium.App.body) -> Response.t Lwt.t

val ignore : ('a, 'b) result Lwt.t -> ('a -> Opium.App.body) -> Response.t Lwt.t
