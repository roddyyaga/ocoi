(** Defines an alternative to [Opium.Std.App.empty] with some default middleware applied *)

open Base

val base : Opium.App.t
(** [App.empty] with the default Opium logger middleware applied *)

val register : Opium.App.builder list -> Opium.App.t -> Opium.App.t
(** Apply a list of handlers to an app *)
