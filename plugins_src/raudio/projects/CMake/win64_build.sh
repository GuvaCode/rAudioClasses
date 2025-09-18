# Создайте отдельную директорию для сборки
mkdir build-windows
cd build-windows

# Запустите CMake с тулчейном
cmake .. -DCMAKE_TOOLCHAIN_FILE=../toolchain-mingw.cmake \
         -DBUILD_RAUDIO_EXAMPLES=ON

# Скомпилируйте проект
make -j$(nproc)
