let migrate_query =
  Caqti_request.exec Caqti_type.unit
   {|CREATE TABLE user (
         id SERIAL PRIMARY KEY NOT NULL,
username VARCHAR NOT NULL,
email VARCHAR NOT NULL,
coolness_rating INT NOT NULL
         )
    |}

let migrate (module Db : Caqti_lwt.CONNECTION) = Db.exec migrate_query ()

let rollback_query = Caqti_request.exec Caqti_type.unit {| DROP TABLE user |}

let rollback (module Db : Caqti_lwt.CONNECTION) = Db.exec rollback_query ()
