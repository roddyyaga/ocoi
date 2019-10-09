(lang dune 1.11)
(name ocoi)
(source (github roddyyaga/ocoi))
(documentation "https://roddyyaga.github.io/ocoi")
(license MIT)
(authors "Roddy MacSween <github@roddymacsween.co.uk>")
(maintainers "Roddy MacSween <github@roddymacsween.co.uk>")
(generate_opam_files true)

(package
(name ocoi)
(synopsis "OCaml On Ice - a backend web framework in the style of Ruby On Rails")
(depends
dune
core
lwt
(opium_core (= "master"))
(opium (= "master"))
ppx_deriving_yojson
caqti
caqti-lwt
caqti-driver-postgresql
lwt_ppx
fileutils
lwt_ppx
)
)
