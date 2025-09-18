# Создайте отдельную директорию для сборки
mkdir build-linux
cd build-linux

#cmake -DGME_YM2612_EMU=MAME ..
cmake -DGME_YM2612_EMU=GENS -DUSE_GME_NSFE=ON ..
# Скомпилируйте проект
make -j$(nproc)
