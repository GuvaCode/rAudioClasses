#!/bin/bash


# hivelytracker ---------------------------------------------------
cd hivelytracker
make clean
make 
cp libhvl.so.1.9.0 ../../dll_libs/x86_64-linux

make clean 
make OS=Windows_NT CC=x86_64-w64-mingw32-gcc AR=x86_64-w64-mingw32-ar 
cp libhvl.so.1.9.0 ../../dll_libs/x86_64-win64/libhvl.dll

cd ..

# build ASAP for linux_64
cd asap
make clean 
make 
cp libasap.so ../../dll_libs/x86_64-linux

# build ASAP for windows_64
make clean 
make OS=Windows_NT CC=x86_64-w64-mingw32-gcc AR=x86_64-w64-mingw32-ar 
mv libasap.so libasap.dll
cp libasap.dll ../../dll_libs/x86_64-win64
cd ..

# build GME for linux_64 - FIXED VERSION
cd game_music_emu_0.6.4
rm -rf build-linux
mkdir build-linux
cd build-linux
cmake -DGME_YM2612_EMU=GENS ..
make
cp gme/libgme.so.0.6.4 ../../../dll_libs/x86_64-linux
cd ..
# build GME for win_64 
rm -rf build-windows
mkdir build-windows
cd build-windows 

cmake -DCMAKE_TOOLCHAIN_FILE=../toolchain-mingw.cmake \
      -DGME_YM2612_EMU=GENS ..
make
cp gme/libgme.dll ../../../dll_libs/x86_64-win64
cd ..



cd raudio/projects/CMake
rm -rf build-linux
mkdir build-linux
cd build-linux
cmake .. 
make 
cp libraudio.so ../../../../../dll_libs/x86_64-linux

cd ..
rm -rf build-windows
mkdir build-windows
cd build-windows
cmake .. -DCMAKE_TOOLCHAIN_FILE=../toolchain-mingw.cmake \
         -DBUILD_RAUDIO_EXAMPLES=OFF
make -j$(nproc)

 cp libraudio.dll ../../../../../dll_libs/x86_64-win64

cd ../../../..

############### ST Sound  lib ###########
cd StSound
rm -rf build-linux
mkdir build-linux
cd build-linux
cmake ..
make
cd StSoundLibrary
cp libStSoundLibrary.so.1.0.0 ../../../../dll_libs/x86_64-linux
cd ../../
rm -rf build-windows
mkdir build-windows
cd build-windows
cmake .. -DCMAKE_TOOLCHAIN_FILE=../toolchain-mingw.cmake 
make -j$(nproc)
cd ..
cd StSoundLibrary/Release
cp libStSoundLibrary.dll ../../../../dll_libs/x86_64-win64
cd ../../../

###################### ZX Tune ###########

cd zxTune
rm -rf build-linux
mkdir build-linux 
cd build-linux
cmake ..
make 
cp libzxtune.so.r4310 ../../../dll_libs/x86_64-linux/libzxtune.so
cd ..

rm -rf build-windows
mkdir build-windows
cd build-windows
cmake .. -DCMAKE_TOOLCHAIN_FILE=../toolchain-mingw.cmake 
make
cp libzxtune.dll ../../../dll_libs/x86_64-win64/libzxtune.dll

cd ../../









