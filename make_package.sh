set -e

REPO=$(pwd)

rm -rf ../linux-*

rm -rf ../prebuilt
rm -rf ../installer

# make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig
# make -j10 deb-pkg
# cp ./arch/arm64/boot/Image ../prebuilt/boot/firmware/kernel8.img

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2712_defconfig
make -j10 deb-pkg

KERNEL_VERSION=$(cat ./include/config/kernel.release)
BUILD_VERSION=$(cat ./.version)

mkdir -p ../prebuilt/dependencies
mkdir -p ../prebuilt/firmware/overlays

mv ../linux-*.deb ../prebuilt/dependencies/
cp ./arch/arm64/boot/Image ../prebuilt/firmware/kernel_2712.img
cp ./arch/arm64/boot/dts/broadcom/*.dtb ../prebuilt/firmware/
cp ./arch/arm64/boot/dts/overlays/*.dtbo ../prebuilt/firmware/overlays/

tree -L 3 ../prebuilt

mkdir -p ../installer
tar -czvf ../installer/novkernel-$KERNEL_VERSION\_$BUILD_VERSION.tar.gz -C ../prebuilt .
cat << 'EOF' > ../installer/install.sh
#!/bin/bash
set -e

echo "Unpacking included dependencies..."
mkdir -p /tmp/novkernel
tar -xzvf ./novkernel-*.tar.gz -C /tmp/novkernel/

echo "Installing included dependencies..."
dpkg -i /tmp/novkernel/dependencies/*.deb
echo "Dependencies installed successfully."

echo "Installing included firmwares..."
cp -rf /boot/firmware /boot/firmware.bak
cp -rf /tmp/novkernel/firmware/* /boot/firmware/
echo "Firmwares installed successfully."

rm -rf /tmp/novkernel
EOF

chmod +x ../installer/install.sh

tree -L 2 ../installer

rm -rf ../prebuilt

# mkdir -p ../prebuilt/DEBIAN
# mkdir -p ../prebuilt/opt/novkernel_$BUILD_VERSION/dependencies
# mkdir -p ../prebuilt/opt/novkernel_$BUILD_VERSION/firmware/overlays

# cp ./arch/arm64/boot/Image ../prebuilt/opt/novkernel_$BUILD_VERSION/firmware/kernel_2712.img
# cp ./arch/arm64/boot/dts/broadcom/*.dtb ../prebuilt/opt/novkernel_$BUILD_VERSION/firmware/
# cp ./arch/arm64/boot/dts/overlays/*.dtbo ../prebuilt/opt/novkernel_$BUILD_VERSION/firmware/overlays/
# # make clean

# mv ../linux-*.deb ../prebuilt/opt/novkernel_$BUILD_VERSION/dependencies/

# cat << 'EOF' > ../prebuilt/DEBIAN/control
# Package: novkernel-KERNEL_VERSION
# Version: BUILD_VERSION
# Architecture: arm64
# Section: kernel
# Depends: dpkg
# Replaces: linux-image, linux-image-rpi-2712, raspberrypi-kernel
# Maintainer: paragonnov <qkdxorjs1002@gmail.com>
# Description: Custom Kernel for uConsole CM5(Lite)
# EOF

# sed -i "s|KERNEL_VERSION|$KERNEL_VERSION|g" ../prebuilt/DEBIAN/control
# sed -i "s|BUILD_VERSION|$BUILD_VERSION|g" ../prebuilt/DEBIAN/control


# cat << 'EOF' > ../prebuilt/DEBIAN/postinst
# #!/bin/bash
# set -e

# echo "Installing included dependencies..."

# cd /opt/novkernel_BUILD_VERSION/dependencies
# dpkg -i *.deb || apt-get install -f -y

# mkdir -p /opt/novkernel_BUILD_VERSION/backup/firmware
# cp -rf /boot/firmware/* /opt/novkernel_BUILD_VERSION/backup/firmware/
# cp -rf /opt/novkernel_BUILD_VERSION/firmware/* /boot/firmware/

# echo "Dependencies installed successfully."
# EOF

# sed -i "s|BUILD_VERSION|$BUILD_VERSION|g" ../prebuilt/DEBIAN/postinst
# chmod +x ../prebuilt/DEBIAN/postinst


# cat << 'EOF' > ../prebuilt/DEBIAN/postrm
# #!/bin/bash
# set -e

# echo "Removing included dependencies..."

# dpkg -r $(dpkg --info /opt/novkernel_BUILD_VERSION/dependencies/*.deb | awk '/Package:/ {print $2}')
# cp -rf /opt/novkernel_BUILD_VERSION/backup/firmware/* /boot/firmware/

# rm -rf /opt/novkernel_BUILD_VERSION

# echo "Dependencies removed successfully."

# EOF

# sed -i "s|BUILD_VERSION|$BUILD_VERSION|g" ../prebuilt/DEBIAN/postrm
# chmod +x ../prebuilt/DEBIAN/postrm


# dpkg-deb --build ../prebuilt ../novkernel-$KERNEL_VERSION\_$BUILD_VERSION.deb
