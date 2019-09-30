#!/usr/bin/env bash
grep -r --exclude-dir _opam --exclude-dir _build "TODO"
