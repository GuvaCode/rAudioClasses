set(PROJECT_NAME StSoundLibrary)

################################################################################
# Source groups
################################################################################
set(Headers
    "digidrum.h"
    "LZH/LZH.H"
    "StSoundLibrary.h"
    "Ym2149Ex.h"
    "YmLoad.h"
    "YmMusic.h"
    "YmTypes.h"
)
source_group("Headers" FILES ${Headers})

set(Sources
    "digidrum.cpp"
    "LZH/LzhLib.cpp"
    "Ym2149Ex.cpp"
    "Ymload.cpp"
    "YmMusic.cpp"
    "YmUserInterface.cpp"
)
source_group("Sources" FILES ${Sources})

set(ALL_FILES
    ${Headers}
    ${Sources}
)

################################################################################
# Target - SHARED библиотека
################################################################################
add_library(${PROJECT_NAME} SHARED ${ALL_FILES})

################################################################################
# Target name
################################################################################
set_target_properties(${PROJECT_NAME} PROPERTIES
    OUTPUT_NAME "StSoundLibrary"
)

################################################################################
# Output directory (только для Windows)
################################################################################
if(WIN32)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/Debug"
        RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/Release"
        LIBRARY_OUTPUT_DIRECTORY_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/Debug"
        LIBRARY_OUTPUT_DIRECTORY_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/Release"
        ARCHIVE_OUTPUT_DIRECTORY_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/Debug"
        ARCHIVE_OUTPUT_DIRECTORY_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/Release"
    )
else()
    # Для Linux используем стандартные выходные директории CMake
    set_target_properties(${PROJECT_NAME} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    )
endif()

################################################################################
# Compile definitions - платформо-зависимые
################################################################################
if(WIN32)
    # Windows-specific definitions
    target_compile_definitions(${PROJECT_NAME} PRIVATE
        $<$<CONFIG:Debug>:_DEBUG>
        $<$<CONFIG:Release>:NDEBUG>
        WIN32
        _WINDOWS
        STSOUND_EXPORTS  # Для экспорта символов из DLL
    )

    # Для импортирующих проектов
    target_compile_definitions(${PROJECT_NAME} PUBLIC
        $<$<NOT:$<BOOL:${BUILD_SHARED_LIBS}>>:STSOUND_STATIC>  # Для статической линковки
    )
else()
    # Linux/Unix definitions
    target_compile_definitions(${PROJECT_NAME} PRIVATE
        $<$<CONFIG:Debug>:_DEBUG>
        $<$<CONFIG:Release>:NDEBUG>
    )
    
    # Для Linux не нужны Windows-specific определения
    target_compile_definitions(${PROJECT_NAME} PUBLIC
        LINUX
        UNIX
    )
endif()

################################################################################
# Настройки компилятора
################################################################################
# Для MSVC (Windows)
if(MSVC)
    target_compile_options(${PROJECT_NAME} PRIVATE
        /W3
        $<$<CONFIG:Debug>:/Od /RTC1>
        $<$<CONFIG:Release>:/O2 /GF /Gy>
    )
    
    target_link_options(${PROJECT_NAME} PRIVATE
        /NOLOGO
        /DLL
    )
    
    # Настройки runtime библиотек
    set_target_properties(${PROJECT_NAME} PROPERTIES
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL"
    )

# Для MinGW/GCC (Windows)
elseif(MINGW)
    target_link_options(${PROJECT_NAME} PRIVATE
        -static-libgcc
        -static-libstdc++
        -static
    )
    
    target_compile_options(${PROJECT_NAME} PRIVATE
        -Wall
        -Wextra
        $<$<CONFIG:Debug>:-O0 -g>
        $<$<CONFIG:Release>:-O2>
    )

# Для GCC/Linux
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    target_compile_options(${PROJECT_NAME} PRIVATE
        -Wall
        -Wextra
        -fPIC  # Position Independent Code для shared libraries на Linux
        $<$<CONFIG:Debug>:-O0 -g>
        $<$<CONFIG:Release>:-O2 -DNDEBUG>
    )
    
    target_link_options(${PROJECT_NAME} PRIVATE
        -fPIC
    )
endif()

################################################################################
# Включение C++11 стандарта
################################################################################
set_target_properties(${PROJECT_NAME} PROPERTIES
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
)

################################################################################
# Версия библиотеки
################################################################################
set_target_properties(${PROJECT_NAME} PROPERTIES
    VERSION 1.0.0
    SOVERSION 1
)

################################################################################
# Дополнительные библиотеки
################################################################################
if(WIN32)
    # Windows libraries
    find_library(WINMM_LIBRARY winmm)
    if(WINMM_LIBRARY)
        target_link_libraries(${PROJECT_NAME} PRIVATE ${WINMM_LIBRARY})
    endif()
    
    # Дополнительные Windows-библиотеки
    target_link_libraries(${PROJECT_NAME} PRIVATE
        kernel32
        user32
        gdi32
        winspool
        shell32
        ole32
        oleaut32
        uuid
        comdlg32
        advapi32
    )
else()
    # Linux libraries
    find_library(PTHREAD_LIBRARY pthread)
    if(PTHREAD_LIBRARY)
        target_link_libraries(${PROJECT_NAME} PRIVATE ${PTHREAD_LIBRARY})
    endif()
    
    find_library(DL_LIBRARY dl)
    if(DL_LIBRARY)
        target_link_libraries(${PROJECT_NAME} PRIVATE ${DL_LIBRARY})
    endif()
    
    find_library(RT_LIBRARY rt)
    if(RT_LIBRARY)
        target_link_libraries(${PROJECT_NAME} PRIVATE ${RT_LIBRARY})
    endif()
endif()

################################################################################
# Include directories
################################################################################
target_include_directories(${PROJECT_NAME} PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include>
)

# Добавляем LZH директорию
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/LZH
)
