# 6502/CMakeLists.txt
cmake_minimum_required(VERSION 3.10)

# Добавьте здесь правила для сборки 6502 ассемблера
# Например, если у вас есть .obx файлы:

# Поиск ассемблера
find_program(XASM_EXECUTABLE xasm PATHS /usr/local/bin /usr/bin)

if(XASM_EXECUTABLE)
    # Пример правила для сборки .obx файлов
    file(GLOB ASM_SOURCES *.asm)
    
    foreach(asm_file ${ASM_SOURCES})
        get_filename_component(target_name ${asm_file} NAME_WE)
        set(obx_file ${target_name}.obx)
        
        add_custom_command(
            OUTPUT ${obx_file}
            COMMAND ${XASM_EXECUTABLE} -q -o ${obx_file} ${asm_file}
            DEPENDS ${asm_file}
            COMMENT "Assembling ${asm_file}"
        )
        
        list(APPEND ASM6502_OBX ${obx_file})
    endforeach()
    
    # Экспортируем переменную для родительского CMakeLists.txt
    set(ASM6502_OBX ${ASM6502_OBX} PARENT_SCOPE)
endif()
