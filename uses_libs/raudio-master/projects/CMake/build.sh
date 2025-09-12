#!/bin/bash

mkdir build

cd build
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=mingw-w64-x86_64.cmake 

#cmake .. \
#    -DCMAKE_TOOLCHAIN_FILE=mingw-w32-x86_64.cmake


cmake --build . 
