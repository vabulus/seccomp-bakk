#!/bin/bash

BIN="$1"
shift
python3 inject-lib.py "$BIN" || exit 1
LD_LIBRARY_PATH=. "${BIN}_patched" "$@"
