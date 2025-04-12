#!/bin/bash
set -e

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabi-

OUTPUT_DIR="../output/uboot"
mkdir -p $OUTPUT_DIR

echo "🔧 配置 U-Boot: stm32mp15_trusted_defconfig"
make stm32mp15_trusted_defconfig

echo "🚀 编译 U-Boot..."
make DEVICE_TREE=stm32mp157c-onedots-512d-v1 all -j$(nproc)

echo "📦 拷贝产物到 $OUTPUT_DIR"
cp -v u-boot.bin u-boot-dtb.bin u-boot-nodtb.bin u-boot.dtb u-boot.stm32 $OUTPUT_DIR/
cp -v u-boot.map u-boot.sym System.map $OUTPUT_DIR/ || true

echo "✅ U-Boot 构建完成，输出位于：$OUTPUT_DIR"

