(** Defines an alternative to [Opium.Std.App.empty] that already has some middleware applied *)

open Opium.Std

val base : App.t
(** [App.empty] with the default Ice logger middleware applied *)
