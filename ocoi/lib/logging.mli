open Opium.Std
(** Provides logging functionality for Ice apps. Logging is done using the {{: https://github.com/dbuenzli/logs} Logs}
    library as in Opium. *)

val default_logger : Rock.Middleware.t
(** The default logger.

    For each request, this logs two info messages, for example {[GET "/path/to/resource"
Responded with 404 Not Found]} *)
