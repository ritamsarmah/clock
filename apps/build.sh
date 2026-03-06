#!/usr/bin/env sh

# Usage: build.sh PROGRAM
# Example: build.sh viz

ld build/*.o -o $1 \
    -lSDL3 -lpthread -ldl -lm -lc \
    -dynamic-linker /lib/ld-linux-aarch64.so.1 \
    -e main::main
