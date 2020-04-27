all: build

build:
	dune build @all

install:
	dune install

test:
	build
	dune runtest

doc:
	dune build @doc
	rm -r docs/ocoi
	cp -r _build/default/_doc/_html/ocoi docs/ocoi

clean:
	dune clean

watch:
	dune build @all --watch
