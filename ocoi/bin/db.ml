open Core

let setup_database name =
  let _create_role =
    Unix.system
      (Printf.sprintf {|psql -U postgres -c "CREATE ROLE %s LOGIN"|} name)
  in
  let _create_db =
    Unix.system
      (Printf.sprintf {|psql -U postgres -c "CREATE DATABASE %s"|} name)
  in
  let _create_schema_migrations_table =
    Unix.system
      (Printf.sprintf
         {|psql -U %s -c "CREATE TABLE schema_migrations (id SERIAL PRIMARY KEY, migration VARCHAR NOT NULL, up BOOL NOT NULL, applied TIMESTAMP NOT NULL)"|}
         name)
  in
  ()
