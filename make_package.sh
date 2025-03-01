set -e

REPO=$(pwd)

rm -rf ../linux-*

rm -rf ../prebuilt
rm -rf ../output

# make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig
# make -j10 deb-pkg LOCALVERSION=-nov
# cp ./arch/arm64/boot/Image ../prebuilt/boot/firmware/kernel8.img

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2712_defconfig
make -j10 deb-pkg LOCALVERSION=-nov


############# MANUAL

# KERNEL_VERSION=$(cat ./include/config/kernel.release)
# BUILD_VERSION=$(cat ./.version)

# mkdir -p ../prebuilt/dependencies
# mkdir -p ../prebuilt/firmware/overlays

# mv ../linux-*.deb ../prebuilt/dependencies/
# cp ./arch/arm64/boot/Image ../prebuilt/firmware/kernel_2712.img
# cp ./arch/arm64/boot/dts/broadcom/*.dtb ../prebuilt/firmware/
# cp ./arch/arm64/boot/dts/overlays/*.dtbo ../prebuilt/firmware/overlays/

# tree -L 3 ../prebuilt

# mkdir -p ../installer
# tar -czvf ../installer/novkernel-$KERNEL_VERSION\_$BUILD_VERSION.tar.gz -C ../prebuilt .
# cat << 'EOF' > ../installer/install.sh
# #!/bin/bash
# set -e

# echo "Backup current kernel..."
# mkdir -p /opt/novkernel/

# echo "Unpacking included dependencies..."
# mkdir -p /tmp/novkernel
# tar -xzvf ./novkernel-*.tar.gz -C /tmp/novkernel/

# echo "Installing included dependencies..."
# dpkg -i /tmp/novkernel/dependencies/*.deb
# echo "Dependencies installed successfully."

# echo "Installing included firmwares..."
# cp -rf /boot/firmware /boot/firmware.bak
# cp -rf /tmp/novkernel/firmware/* /boot/firmware/
# echo "Firmwares installed successfully."

# rm -rf /tmp/novkernel
# EOF

# chmod +x ../installer/install.sh

# tree -L 2 ../installer

# rm -rf ../prebuilt


############# DEB PACK

KERNEL_VERSION=$(cat ./include/config/kernel.release)
BUILD_VERSION=$(cat ./.version)

mkdir -p ../prebuilt/boot/firmware/overlays

dpkg-deb -R ../linux-headers-*.deb ../prebuilt/
rm -rf ../prebuilt/DEBIAN
dpkg-deb -R ../linux-libc-*.deb ../prebuilt/
rm -rf ../prebuilt/DEBIAN
dpkg-deb -R ../linux-image-*.deb ../prebuilt/
rm -rf ../prebuilt/DEBIAN/control

cp ./arch/arm64/boot/Image ../prebuilt/boot/firmware/kernel_2712.img
cp ./arch/arm64/boot/dts/broadcom/*.dtb ../prebuilt/boot/firmware/
cp ./arch/arm64/boot/dts/overlays/*.dtbo ../prebuilt/boot/firmware/overlays/

find ../prebuilt/boot/firmware/ -type f \( -name "*.dtb" -o -name "*.dtbo" -o -name "*.img" \) | while read file; do
    relative_path=$(realpath --relative-to=../prebuilt/boot/firmware/ "$file")
    sed -i "/^set -e/a rm -vf /boot/firmware/$relative_path" ../prebuilt/DEBIAN/preinst
done
sed -i "/^set -e/a cp -rvf /boot/firmware /boot/firmware.$BUILD_VERSION.bak" ../prebuilt/DEBIAN/preinst
sed -i "/^set -e/a\
if [ \"\$1\" = \"remove\" ]; then\n\
    cp -rvf /boot/firmware.$BUILD_VERSION.bak/* /boot/firmware/\n\
    rm -rvf /boot/firmware.$BUILD_VERSION.bak\n\
fi\n\
" ../prebuilt/DEBIAN/postrm

cat << 'EOF' > ../prebuilt/DEBIAN/control
Package: novkernel-KERNEL_VERSION
Source: linux-upstream
Version: BUILD_VERSION
Architecture: arm64
Maintainer: paragonnov <qkdxorjs1002@gmail.com>
Section: kernel
Priority: optional
Provides: linux-image, linux-kernel-headers, linux-libc-dev
Conflicts: linux-image, linux-kernel-headers, linux-libc-dev, linux-image-rpi-2712, raspberrypi-kernel, clockworkpi-cm-firmware, clockworkpi-kernel
Replaces: linux-image, linux-kernel-headers, linux-libc-dev, linux-image-rpi-2712, raspberrypi-kernel, clockworkpi-cm-firmware, clockworkpi-kernel
Description: Custom Kernel for uConsole CM5(Lite)
EOF

sed -i "s|KERNEL_VERSION|$KERNEL_VERSION|g" ../prebuilt/DEBIAN/control
sed -i "s|BUILD_VERSION|$BUILD_VERSION|g" ../prebuilt/DEBIAN/control

mkdir -p ../output
dpkg-deb --build ../prebuilt ../output/novkernel-$KERNEL_VERSION\_$BUILD_VERSION.deb
