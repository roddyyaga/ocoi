let migrate_query =
  Caqti_request.exec Caqti_type.unit
   {|CREATE TABLE test (
         id SERIAL PRIMARY KEY NOT NULL,
bla INT NOT NULL,
is_something BOOLEAN NOT NULL,
another_field VARCHAR NOT NULL
         )
    |}

let migrate (module Db : Caqti_lwt.CONNECTION) = Db.exec migrate_query ()

let rollback_query = Caqti_request.exec Caqti_type.unit {| DROP TABLE test |}

let rollback (module Db : Caqti_lwt.CONNECTION) = Db.exec rollback_query ()
