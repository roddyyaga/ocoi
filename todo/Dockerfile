FROM ocaml/opam2:alpine

WORKDIR /app

ADD todo.opam .

RUN opam pin -yn todo . && \
    opam install --deps-only todo

ADD . .
RUN opam config exec make build
