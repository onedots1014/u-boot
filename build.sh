export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabi-
make stm32mp15_trusted_defconfig
make DEVICE_TREE=stm32mp157c-onedots-512d-v1 all -j4
