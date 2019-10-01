# OCaml On Ice

OCaml On Ice is a planned web framework in the style of Ruby on Rails or Django, but in OCaml. Initially it will be an
extension of [Opium](https://github.com/rgrinberg/opium) plus some code generation tools. It is designed primarily for
building REST APIs. In particular, it should work well for REST APIs that are consumed by ReasonML frontends (for
instance it should be simple to share code between frontend and backend with that setup).

## Tutorial
### Format
This tutorial 
### Installation
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
:monorail: This should look fairly familiar if you've used frameworks such as rails in the past. Some of the
  similarlities may be deceptive though. For example, Ice doesn't have an ORM (or indeed objects at all!) so models look
  different. The structure is designed so that the content of `/models` is self-conained and could be shared with
  frontend code in ReasonML/BuckleScript or js\_of\_ocaml.

In another terminal, go into the app directory and start the server:
```
other_terminal$ cd todo/app && ocoi server
```

- :dromedary_camel: Ice projects are built with dune using `main.ml` as an entry point (which starts an Opium server).
  The `ocoi server` command just watches your source code and does `dune exec -- ./main.exe` when something changes.

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

