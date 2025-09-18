#!/bin/bash
cd libopenmpt-0.8.3
make clean
./configure --host=x86_64-w64-mingw32 \
            CC=x86_64-w64-mingw32-gcc-posix \
            CXX=x86_64-w64-mingw32-g++-posix \
            --enable-shared \
            --disable-static \
            --disable-examples \
            --disable-openmpt123 \
            --disable-tests \
            --without-mpg123 \
            --without-flac \
            --without-ogg \
            --without-vorbis \
            --without-vorbisfile \
            --without-zlib \
            LDFLAGS="-Wl,-Bstatic -lstdc++ -lgcc -lwinpthread -lz -Wl,-Bdynamic"
make 
strip libopenmpt-0.dll
cp .libs/libopenmpt-0.dll ../../dll_libs/x86_64-win64/libopenmpt.dll
