(** Defines an alternative to [Opium.Std.App.empty] that already has some middleware applied *)

open Base
open Opium.Std

val base : App.t
(** [App.empty] with the default Ice logger middleware applied *)

val register : Opium.App.t -> Opium.App.builder list -> Opium.App.t
(** Apply a list of handlers to an app *)
