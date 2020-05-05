(** Defines various functions involving databases *)

val make_pool :
  string ->
  ((module Caqti_lwt.CONNECTION), [> Caqti_error.connect ]) Caqti_lwt.Pool.t
(** [make_pool uri] makes a pool of oconnections to a database with the specified URI

    The URI should be something like ["postgresql://username:password@localhost:5432/postgres"]. *)

(** [transaction query] returns a query that wraps [query] in a transaction that will only be committed if [query] returns [Ok] *)
val transaction :
  ((module Caqti_lwt.CONNECTION) ->
  ('a, ([> Caqti_error.transact ] as 'b)) result Lwt.t) ->
  (module Caqti_lwt.CONNECTION) ->
  ('a, 'b) result Lwt.t
