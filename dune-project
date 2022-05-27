(lang dune 2.0)

(name ocoi)

(version 0.1)

(source
 (github roddyyaga/ocoi))

(documentation "https://roddyyaga.github.io/ocoi")

(license MIT)

(authors "Roddy MacSween <github@roddymacsween.co.uk>")

(maintainers "Roddy MacSween <github@roddymacsween.co.uk>")

(generate_opam_files true)

(package
 (name ocoi)
 (synopsis
   "OCaml On Ice - a backend web framework in the style of Ruby On Rails")
 (depends
  core
  lwt
  (opium
   (>= "0.19.0"))
  caqti
  caqti-lwt
  caqti-driver-postgresql
  jose
  fileutils
  lwt_ppx
  ppx_yojson_conv
  ppx_yojson
  ppx_let
  ocamlformat
  ppx_rapper
  ppx_rapper_lwt
  jingoo))

(package
 (name ppx_ocoi)
 (synopsis "PPXs for OCaml On Ice")
 (depends
  (ppxlib
   (>= "0.13"))
  ppx_optcomp))

(package
 (name js_ocoi)
 (synopsis "For js_of_ocaml frontends to OCaml On Ice applications")
 (depends js_of_ocaml ezjs_fetch))
