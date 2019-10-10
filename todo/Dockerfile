FROM ocaml/opam2:alpine

WORKDIR /app

ADD app.opam .

RUN opam pin -yn app . && \
    opam install --deps-only app

ADD . .
RUN opam config exec make build
