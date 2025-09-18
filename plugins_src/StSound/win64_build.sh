# Создайте отдельную директорию для сборки
mkdir build-windows
cd build-windows

# Запустите CMake с тулчейном
cmake .. -DCMAKE_TOOLCHAIN_FILE=../toolchain-mingw.cmake \


# Скомпилируйте проект
make -j$(nproc)
