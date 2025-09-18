cmake_minimum_required(VERSION 3.28)

set(NAME "zxtune")
set(VERSION "r4310")
project(${NAME})

set(CMAKE_C_STANDARD 17)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_BUILD_TYPE Release)
# Используем локальный zxtune-r4310 вместо скачивания
set(NAME_VERSIONED "${NAME}-${VERSION}")
set(EXTERNAL_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/zxtune-r4310")  # Путь к локальной копии

# Проверяем, что каталог существует
if(NOT EXISTS "${EXTERNAL_SOURCE_DIR}")
    message(FATAL_ERROR "Локальная копия zxtune-r4310 не найдена! Положите её в ${CMAKE_CURRENT_SOURCE_DIR}/zxtune-r4310")
endif()

# Собираем список исходников (проверьте пути!)
file(GLOB SOURCES
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/crc16.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/ext_header.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/lh1_decoder.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/lh5_decoder.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/lh6_decoder.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/lh7_decoder.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/lha_arch_unix.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/lha_arch_win32.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/lha_basic_reader.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/lha_decoder.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/lha_endian.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/lha_file_header.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/lha_input_stream.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/lha_reader.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/lz5_decoder.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/lzs_decoder.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/macbinary.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/null_decoder.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib/pm2_decoder.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/z80ex/z80ex.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/zlib/adler32.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/zlib/compress.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/zlib/crc32.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/zlib/deflate.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/zlib/inffast.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/zlib/inflate.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/zlib/inftrees.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/zlib/trees.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/zlib/uncompr.c
        ${EXTERNAL_SOURCE_DIR}/3rdparty/zlib/zutil.c
        ${EXTERNAL_SOURCE_DIR}/libzxtune/src/zxtune.cpp
        ${EXTERNAL_SOURCE_DIR}/src/analysis/src/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/binary/compression/src/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/binary/format/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/binary/src/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/plugins/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/plugins/archives/stub/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/plugins/players/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/plugins/players/ay/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/plugins/players/dac/chi_supp.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/plugins/players/dac/dac_plugin.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/plugins/players/dac/dmm_supp.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/plugins/players/dac/dst_supp.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/plugins/players/dac/et1_supp.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/plugins/players/dac/pdt_supp.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/plugins/players/dac/sqd_supp.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/plugins/players/dac/str_supp.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/plugins/players/saa/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/plugins/players/tfm/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/src/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/core/text/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/debug/src/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/devices/aym/src/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/devices/beeper/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/devices/dac/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/devices/fm/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/devices/saa/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/devices/z80/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/formats/chiptune/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/formats/chiptune/aym/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/formats/chiptune/digital/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/formats/chiptune/emulation/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/formats/chiptune/fm/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/formats/chiptune/multidevice/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/formats/chiptune/multitrack/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/formats/chiptune/saa/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/formats/multitrack/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/formats/packed/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/formats/text/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/l10n/stub/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/players/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/players/aym/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/players/dac/chiptracker.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/players/dac/dac_base.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/players/dac/dac_parameters.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/players/dac/dac_properties_helper.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/players/dac/dac_simple.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/players/dac/digitalmusicmaker.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/players/dac/digitalstudio.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/players/dac/extremetracker1.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/players/dac/prodigitracker.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/players/dac/sampletracker.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/players/dac/sqdigitaltracker.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/players/saa/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/players/tfm/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/src/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/module/text/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/parameters/src/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/platform/version/src/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/platform/version/text/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/sound/impl/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/strings/src/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/strings/text/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/tools/src/*.cpp
        ${EXTERNAL_SOURCE_DIR}/src/tools/text/*.cpp
        )

# Проверяем, что файлы найдены
if(NOT SOURCES)
    message(FATAL_ERROR "Не найдены исходные файлы в ${EXTERNAL_SOURCE_DIR}. Проверьте структуру каталогов!")
endif()

# Включение позиционно-независимого кода для shared библиотек
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_library(${PROJECT_NAME} SHARED ${SOURCES})

# КРИТИЧЕСКИ ВАЖНО: полная статическая линковка
if(MINGW)
    target_link_options(${PROJECT_NAME} PRIVATE
        -static-libgcc
        -static-libstdc++
        -static
    )
endif()


# Убираем статическую линковку для shared библиотеки
# Вместо этого используем динамическую линковку для shared библиотеки

target_include_directories(${PROJECT_NAME} PRIVATE
    "${EXTERNAL_SOURCE_DIR}"
    "${EXTERNAL_SOURCE_DIR}/3rdparty/lhasa/lib"
    "${EXTERNAL_SOURCE_DIR}/3rdparty/boost_1_66_0"
    "${EXTERNAL_SOURCE_DIR}/3rdparty/z80ex/include"
    "${EXTERNAL_SOURCE_DIR}/include"
    "${EXTERNAL_SOURCE_DIR}/src"
    "${CMAKE_SOURCE_DIR}/libzxtune"
)

target_compile_definitions(${PROJECT_NAME} PRIVATE
    Z80EX_API_REVISION=1
    Z80EX_VERSION_MAJOR=1
    Z80EX_VERSION_MINOR=19
)

# Флаги компилятора для Linux
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    target_compile_options(${PROJECT_NAME} PRIVATE
        -Wall
        -Wextra
        -fPIC
        $<$<CONFIG:Release>:-O2>
        $<$<CONFIG:Debug>:-O0 -g>
    )
endif()

set_target_properties(${PROJECT_NAME} PROPERTIES
    OUTPUT_NAME "libzxtune"
    PREFIX ""
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
    VERSION ${VERSION}
    SOVERSION 1
)

# Дополнительные системные библиотеки для Linux
if(UNIX AND NOT APPLE)
    find_library(PTHREAD_LIBRARY pthread)
    find_library(DL_LIBRARY dl)
    find_library(M_LIBRARY m)
    
    if(PTHREAD_LIBRARY)
        target_link_libraries(${PROJECT_NAME} PRIVATE ${PTHREAD_LIBRARY})
    endif()
    if(DL_LIBRARY)
        target_link_libraries(${PROJECT_NAME} PRIVATE ${DL_LIBRARY})
    endif()
    if(M_LIBRARY)
        target_link_libraries(${PROJECT_NAME} PRIVATE ${M_LIBRARY})
    endif()
endif()
