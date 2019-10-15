# Build the app
FROM ocaml/opam2:alpine

WORKDIR /app

COPY app.opam .

RUN opam switch 4.07 && eval $(opam env)
RUN opam pin -yn app .
RUN opam depext app
RUN opam install --deps-only app
ADD . .
# TODO - figure out exactly why chown necessary
# (taken from here https://medium.com/@bobbypriambodo/lightweight-ocaml-docker-images-with-multi-stage-builds-f7a060c7fce4)
# TODO - work out why the `eval` and `dune build` have to be in the same RUN step
# TODO - see if there is a better solution to copying depexts to production than this one
# (taken from same blog post)
# TODO - determine whether removing the egrep and sed from that post in the depext command was correct
RUN eval $(opam env) && sudo chown -R opam:nogroup . && dune build @install && opam depext -ln app > depexts

# Create the production image
FROM alpine
WORKDIR /app
COPY --from=0 /app/_build/install/default/bin/main main.exe

COPY --from=0 /app/depexts depexts
RUN cat depexts | xargs apk --update add && rm -rf /var/cache/apk/*

EXPOSE 3000
CMD ./main.exe -d
