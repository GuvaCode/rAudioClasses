#!/bin/bash
cd libopenmpt-0.8.3
make clean

# Используем специфичные флаги для MinGW
export LDFLAGS="-Wl,-Bstatic -lstdc++ -lgcc -lwinpthread -lz -Wl,-Bdynamic -static-libgcc -static-libstdc++"

./configure --host=x86_64-w64-mingw32 \
            CC="x86_64-w64-mingw32-gcc-posix -static-libgcc -static-libstdc++" \
            CXX="x86_64-w64-mingw32-g++-posix -static-libgcc -static-libstdc++" \
            --enable-shared \
            --disable-static \
            --disable-examples \
            --disable-openmpt123 \
            --disable-tests \
            --without-mpg123 \
            --without-flac \
            --without-ogg \
            --without-vorbis \
            --without-vorbisfile

make 
strip libopenmpt-0.dll

# Финальная проверка и копирование
x86_64-w64-mingw32-objdump -p .libs/libopenmpt-0.dll | grep 'DLL Name'
cp .libs/libopenmpt-0.dll ../../dll_libs/x86_64-win64/libopenmpt.dll
