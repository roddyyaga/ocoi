let migrate_query =
  Caqti_request.exec Caqti_type.unit
   {|CREATE TABLE todo (
         id SERIAL PRIMARY KEY NOT NULL,
title VARCHAR NOT NULL,
completed BOOLEAN NOT NULL
         )
    |}

let migrate (module Db : Caqti_lwt.CONNECTION) = Db.exec migrate_query ()

let rollback_query = Caqti_request.exec Caqti_type.unit {| DROP TABLE todo |}

let rollback (module Db : Caqti_lwt.CONNECTION) = Db.exec rollback_query ()
