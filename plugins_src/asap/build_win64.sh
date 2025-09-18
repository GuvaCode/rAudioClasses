#!/bin/bash
make clean 
make OS=Windows_NT CC=x86_64-w64-mingw32-gcc AR=x86_64-w64-mingw32-ar 
mv libasap.so libasap.dll
