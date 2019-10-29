#!/usr/bin/env bash

mkdir -p build

gcc -framework Cocoa \
  -framework AudioToolbox \
  code/macos_handmade.mm \
  -o build/handmade
