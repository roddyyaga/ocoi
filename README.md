# OCaml On Ice

OCaml On Ice is a planned web framework in the style of Ruby on Rails or Django, but in OCaml. Initially it will be an
extension of [Opium](https://github.com/rgrinberg/opium) plus some code generation tools. It is designed primarily for
building REST APIs. In particular, it should work well for REST APIs that are consumed by ReasonML frontends (for
instance it should be simple to share code between frontend and backend with that setup).

## Tutorial
The classic web framework tutorial -- building a todo app. It should make sense even if you don't know any OCaml or web
development. As well as a list of steps and general notes, this tutorial contains some asides labeled with
:dromedary_camel: (oCamel) and :monorail: ((Ruby on) rails) aimed at people with experience in OCaml and other web
frameworks respectively.

### Installation
Ice has only been tested on Linux (Ubuntu) but should in theory work on any flavour of Unix. Dependencies are OCaml (developed with 4.07.0), PostgreSQL
and inotify-tools (to automatically rebuild/restart the server when source files change).
Build and install from source (it's not on OPAM yet):
```
$ dune build @install && dune install
```
Check the install worked:
```
$ ocoi version
```

### Creating a project
Use the `ocoi` command to create a new project:
```
$ ocoi new todo
```
This will produce directories and files like this:
```
/todo
    /app
        /models
            dune
        /controllers
            dune
        /queries
            dune
        /db
            /migrate
            dune
            db.ml
        .ocamlformat
        dune
        dune-project
        main.ml
```
- :monorail: This should look fairly familiar if you've used frameworks such as rails in the past. Some of the
  similarlities might be deceptive though.

  In another terminal, go into the app directory and start the server:
```
another_terminal$ cd todo/app && ocoi server
```
- :dromedary_camel: Ice projects are built with dune using `main.ml` as an entry point (which starts an Opium server).
  The `ocoi server` command just watches your source code and does `dune exec -- ./main.exe` when something changes.

Check that the server is up (on port 3000 by default) using [HTTPie](https://httpie.org/):
```
$ http localhost:3000
HTTP/1.1 200 OK
content-length: 33

Hello world!

from OCaml
     Ice

```
Alternatively you can go to `http://localhost:3000/` in a browser.

### Adding a resource
Now we can start building the actual app. The first step here is defining a resource to represent todo items. In Ice,
this is done using a type in a file in the `models` directory:
```
$ echo "type t = {id: int; title: string; completed: bool} [@@deriving yojson]" > models/todo.ml
```
We also add a plugin to automatically generate functions for JSON (de)serialisation.

- :monorail: This demonstrates one of the differences between Ice and rails or Django: models don't know how to
  interact with the database (there is no ORM!) but they can convert to and from JSON. One of the reasons for this setup
  is to facilitate sharing of model code with frontends written in ReasonML/BuckleScript or js\_of\_ocaml.

For this to be useful we need some code to persist todos to a database and do things with them based on requests to the
server. To start with, we want standard CRUD functionality (allowing todos to be Created, Read, Updated and Deleted)
and also have these operations exposed as a REST API. Ice can generate all of this code from the type in `models/todo.ml`:
```
$ ocoi generate scaffold models/todo.ml
```
This creates two more files called `todo.ml`, one in `/queries` and one in `/controllers`. The `queries` file contains
queries that use the Caqti library to interact with a Postgres database. The `controllers` file defines the interface
between requests to the API and database operations or other things on the model layer. Also, two files in
`db/migrate` called `todo_migrate.ml` and `todo_rollback.ml` are created, which we will need shortly.

### Using the todo resource
#### Creating handlers for CRUD operations
TODO - explanation about controllers
Edit `main.ml` to register the CRUD operations from the todo controller by changing it to this:
```ocaml
open Core
open Opium.Std
open Controllers

let hello_world =
  get "/" (fun _ ->
      `String "Hello world!\n\nfrom OCaml\n     Ice" |> respond')

let _ =
  let app = App.empty in
  app
  |> Ocoi.Controllers.register_crud "/todos" (module Todo.Crud)
  |> hello_world |> App.run_command
```
Check out the todos resource:
```
$ http localhost:3000/todos
```
(or go to `http://localhost:3000/todos` in a browser).
You should get an error saying the `todo` relation doesn't exist. This is expected because we haven't created the table
for todos yet. The table can be created by running migrations.
```
$ ocoi db migrate todo
```
Now `http localhost:3000/todos` should return an empty list:
```
$ http localhost:3000/todos
HTTP/1.1 200 OK
content-length: 2
content-type: application/json

[]

```

The other CRUD operations also work.
Create:
```
$ http post localhost:3000/todos title="Complete me!" completed := false
HTTP/1.1 201 Created
content-length: 0
location: /todos/1



```
Read (a single instance):
```
$ http get localhost:3000/todos/1
```
Update:
```
$ http put localhost:3000/todos id:=1 title="Complete me! completed := true
```
And Delete:
```
$ http delete localhost:3000/todos/1
```

## Features
### Scaffold generation
#### Models
#### Controllers

## Dependencies
OCaml On Ice uses Jane Street's Core as a standard library, Opium for handling requests and Caqti for accessing a
database. Currently Caqti code generation targets Postgresql.

## FAQ
### 

