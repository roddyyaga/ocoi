(** Defines various functions involving databases *)

val handle_caqti_result : ('a, [< Caqti_error.t]) result Lwt.t -> 'a Lwt.t
(** [handle_caqti_result query_result] returns the data in [query_result] if it succees or handles the error if not

    Currently the "handling" in the error case is just throwing an error. *)

val get_connection : string -> Caqti_lwt.connection Lwt.t
(** [get_connection uri] connects to the database with the specified URI

    The URI should be something like ["postgresql://username:password@localhost:5432/postgres"]. *)
