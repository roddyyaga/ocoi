#!/usr/bin/env bash
# Build the docs and move them to the correct place
rm -r docs/ocoi
dune clean && dune build @doc
cp -r _build/default/_doc/_html/ocoi docs/ocoi
