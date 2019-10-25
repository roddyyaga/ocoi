# OCaml On Ice
OCaml On Ice is a web framework in the style of Ruby on Rails, built on top of
[Opium](https://github.com/rgrinberg/opium). It is designed for building REST APIs, espeically ones that are consumed by
BuckleScript or js\_of\_ocaml frontends. Documentation is [here](https://roddyyaga.github.io/ocoi/ocoi/index.html).

### Installation
Ice isn't on OPAM yet as it relies on the master version of Opium. You can install it with `git clone git@github.com:roddyyaga/ocoi.git && cd ocoi/ocoi && opam install .`. It also depends on PostgreSQL and [inotify-tools](https://github.com/rvoicilas/inotify-tools/wiki).
To check the install worked:
```
$ ocoi version
```
