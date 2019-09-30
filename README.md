# OCaml On Ice

OCaml On Ice is a planned web framework in the style of Ruby on Rails or Django, but in OCaml. Initially it will be a
wrapper around [Opium](https://github.com/rgrinberg/opium) plus some code generation tools. It is designed primarily for
building REST APIs. In particular, it should work well for REST APIs that are consumed by ReasonML frontends (for
instance it should be simple to share code between frontend and backend with that setup).

## Quickstart
Create a new project using `ocoi new`. This will have the following structure:
```
/app
    /models
    /controllers
    /db
    main.ml
```

## Features
### Scaffold generation
#### Models
#### Controllers

## Dependencies
OCaml On Ice uses Jane Street's Core as a standard library, Opium for handling requests and Caqti for accessing a
database. Currently Caqti code generation targets Postgresql.
