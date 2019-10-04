#!/usr/bin/env bash
# A script containing the steps to build the project in the tutorial
ocoi new todo
cd todo/app
echo "type t = {id: int; title: string; completed: bool} [@@deriving yojson]" >> models/todo.ml
ocoi generate scaffold models/todo.ml
