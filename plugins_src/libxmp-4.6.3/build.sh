#!/bin/bash


rm -rf build-windows
mkdir build-windows
cd build-windows

# CMake с тулчейном
cmake .. -DCMAKE_TOOLCHAIN_FILE=../toolchain-mingw.cmake \
         -DBUILD_STATIC=OFF \
         -DBUILD_SHARED=ON

make -j$(nproc)
ls
cp libxmp.dll ../../../dll_libs/x86_64-win64/libxmp.dll
cd ..

rm -rf build-linux
mkdir build-linux 
cd build-linux

cmake .. -DBUILD_STATIC=OFF \
         -DBUILD_SHARED=ON

make -j$(nproc)
cp libxmp.so.4.6.3 ../../../dll_libs/x86_64-linux/libxmp.so.4.6.3 

cd ..
rm -rf build-windows
rm -rf build-linux


