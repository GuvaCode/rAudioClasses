#!/bin/bash
cd libopenmpt-0.8.3

#Сборка Linux версии (native)

make clean
./configure --enable-shared \
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



strip .libs/libopenmpt.so.0.5.5
cp .libs/libopenmpt.so.0.5.5 ../../dll_libs/x86_64-linux/libopenmpt.so.5
