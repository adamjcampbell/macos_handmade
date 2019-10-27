#!/usr/bin/env bash

mkdir -p build

gcc -framework Cocoa \
  code/macos_handmade.mm \
  -o build/handmade
