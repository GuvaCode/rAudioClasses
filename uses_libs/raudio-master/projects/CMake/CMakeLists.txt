cmake_minimum_required(VERSION 3.11)
project(raudio
    DESCRIPTION "raudio: A simple and easy-to-use audio library based on miniaudio"
    HOMEPAGE_URL "https://github.com/raylib5/raudio"
    LANGUAGES C
)


# Directory Variables
set(RAUDIO_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../..)
set(RAUDIO_SRC ${RAUDIO_ROOT}/src)


option(SUPPORT_FILEFORMAT_WAV "WAV Support" TRUE)
option(SUPPORT_FILEFORMAT_OGG "OGG Support" TRUE)
option(SUPPORT_FILEFORMAT_MP3 "MP3 Support" TRUE)
option(SUPPORT_FILEFORMAT_QOA "QOA Support" TRUE)
option(SUPPORT_FILEFORMAT_FLAC "FLAC Support" TRUE)
option(SUPPORT_FILEFORMAT_XM "XM Support" TRUE)
option(SUPPORT_FILEFORMAT_MOD "MOD Support" TRUE)

# raudio
add_library(raudio SHARED
    ${RAUDIO_SRC}/raudio.c
)

# Includes
target_include_directories(raudio INTERFACE ${RAUDIO_SRC})

# Defines
target_compile_definitions(raudio PUBLIC
    RAUDIO_STANDALONE
    SUPPORT_MODULE_RAUDIO
)

# Dependenices
target_link_libraries(raudio
    m # math
)

# Audio file support options
if (SUPPORT_FILEFORMAT_WAV)
    target_compile_definitions(raudio PUBLIC SUPPORT_FILEFORMAT_WAV)
endif()
if (SUPPORT_FILEFORMAT_OGG)
    target_compile_definitions(raudio PUBLIC SUPPORT_FILEFORMAT_OGG)
endif()
if (SUPPORT_FILEFORMAT_MP3)
    target_compile_definitions(raudio PUBLIC SUPPORT_FILEFORMAT_MP3)
endif()
if (SUPPORT_FILEFORMAT_QOA)
    target_compile_definitions(raudio PUBLIC SUPPORT_FILEFORMAT_QOA)
endif()
if (SUPPORT_FILEFORMAT_FLAC)
    target_compile_definitions(raudio PUBLIC SUPPORT_FILEFORMAT_FLAC)
endif()
if (SUPPORT_FILEFORMAT_XM)
    target_compile_definitions(raudio PUBLIC SUPPORT_FILEFORMAT_XM)
endif()
if (SUPPORT_FILEFORMAT_MOD)
    target_compile_definitions(raudio PUBLIC SUPPORT_FILEFORMAT_MOD)
endif()


