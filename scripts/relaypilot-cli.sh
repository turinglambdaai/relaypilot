#!/bin/sh
# Dev/CI shim: run the RelayPilot CLI through the system racket.
exec racket "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/app/cli.rkt" "$@"
