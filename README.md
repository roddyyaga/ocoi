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

Checking that the server is up (on port 3000 by default) using [HTTPie](https://httpie.org/):
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
$ echo "type t = {id: int; title: string; completed: bool} [@@deriving yojson]" >> models/todo.ml
```
We also add a plugin to automatically generate functions for JSON (de)serialisation.

- :monorail: This demonstrates one of the differences between Ice and rails or Django: models don't know how to
  interact with the database (there is no ORM!) but they can convert to and from JSON. One of the reasons for this setup
  is to facilitate sharing of model code with frontends written in ReasonML/BuckleScript or js\_of\_ocaml.

For this to be useful we need some code to persist todos to a database and do things with them based on requests to the
server. Specifically, we want to implement CRUD functionality (allowing todos to be Created, Read, Updated and Deleted)
and expose these operations as a REST API. Ice can generate all of this code from the type in `models/todo.ml`:
```
$ ocoi generate scaffold models/todo.ml
```
This creates two more files called `todo.ml`, one in `/queries` and one in `/controllers`, and also migrations. The `queries` file contains
queries that use the Caqti library to interact with a Postgres database. The `controllers` file.

### Creating a project
First install Ice. It isn't on OPAM yet, so build from source then install manually with `dune build @install
&& dune install` (after installing any dependencies).

### Creating a project
Then check it has been installed by doing `ocoi version`. Create a new project  `ocoi new todo`. This will have the following structure:
```
/todo
    /app
        /models
            dune
        /controllers
            dune
        .ocamlformat
        dune
        dune-project
        main.ml
```
Now if you do `cd todo/app` followed by `ocoi server` and open `localhost:3000` in a browser you will see a hello world page!

### Adding a resource
As is traditional, we will start out by building a simple todo app. The obvious first step is creating a resource to
represent a todo item. We will represent this with a simple OCaml record type `{id: int; title: string; completed:
bool}`. In Ice, resources are specified with modules containing types such as this in the models directory. So create a
new file `models/todo.ml` and edit it to contain `type t = {id: int; title: string; completed: bool} [@@deriving yojson]`.

To use this type we need need some more code, for instance to store it in a database and perform operations with it when
the server gets requests. 

## Features
### Scaffold generation
#### Models
#### Controllers

## Dependencies
OCaml On Ice uses Jane Street's Core as a standard library, Opium for handling requests and Caqti for accessing a
database. Currently Caqti code generation targets Postgresql.

## FAQ
### 

