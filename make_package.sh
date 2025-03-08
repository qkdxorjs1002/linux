set -e

REPO=$(pwd)

rm -rf ../linux-*

rm -rf ../prebuilt*
rm -rf ../output

# make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig
# make -j10 deb-pkg LOCALVERSION=-nov
# cp ./arch/arm64/boot/Image ../prebuilt/boot/firmware/kernel8.img

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2712_defconfig
make -j10 deb-pkg LOCALVERSION=-nov

KERNEL_IMAGE="./arch/arm64/boot/Image"
DTB_OVERLAYS="./arch/arm64/boot/dts"
KERNEL_VERSION=$(cat ./include/config/kernel.release)
BUILD_VERSION=$(cat ./.version)
OUTPUT="../output"


############# MANUAL

MANUAL_PREBUILT="../prebuilt-man"
MANUAL_OUTPUT="$OUTPUT/manual"

mkdir -p $MANUAL_PREBUILT/dependencies
mkdir -p $MANUAL_PREBUILT/firmware/overlays

dpkg-deb -R ../linux-headers-*.deb $MANUAL_PREBUILT/dependencies
rm -rf $MANUAL_PREBUILT/dependencies/DEBIAN
dpkg-deb -R ../linux-libc-*.deb $MANUAL_PREBUILT/dependencies
rm -rf $MANUAL_PREBUILT/dependencies/DEBIAN
dpkg-deb -R ../linux-image-*.deb $MANUAL_PREBUILT/dependencies
rm -rf $MANUAL_PREBUILT/dependencies/DEBIAN

cp $KERNEL_IMAGE $MANUAL_PREBUILT/firmware/kernel_2712.img
cp $DTB_OVERLAYS/broadcom/*.dtb $MANUAL_PREBUILT/firmware/
cp $DTB_OVERLAYS/overlays/*.dtbo $MANUAL_PREBUILT/firmware/overlays/

tree -L 3 $MANUAL_PREBUILT

mkdir -p $MANUAL_OUTPUT
tar -czvf $MANUAL_OUTPUT/novkernel-$BUILD_VERSION.tar.gz -C $MANUAL_PREBUILT .
cat << 'EOF' > $MANUAL_OUTPUT/install.sh
#!/bin/bash
set -e

TMP_PATH="/tmp/novkernel"
OPT_PATH="/opt/novkernel.BUILD_VERSION"
BOOT_PATH=""

echo "##################################"
echo "### NovKernel for uConsole CM5 ###"
echo "##################################"
echo ""
echo ""
echo "Press any key to install kernel..."
read TEST

echo "Detect boot sturucture..."
if [ -e "/boot/firmware/bootcode.bin" ]; then
    echo "'/boot/firmware' found."
    BOOT_PATH="/boot/firmware"
elif [ -e "/boot/bootcode.bin" ]; then
    echo "'/boot' found."
    BOOT_PATH="/boot"
else 
    echo "There's no supported boot structure found."
    exit;
fi

sleep 2

echo ""
echo ""
echo ""
echo "Backup current kernel..."
mkdir -p $OPT_PATH/backup
cp -rf $BOOT_PATH $OPT_PATH/backup

echo ""
echo "Unpacking included dependencies..."
mkdir -p $TMP_PATH
tar -xzf ./novkernel-BUILD_VERSION.tar.gz -C $TMP_PATH/

echo ""
echo "Installing included dependencies..."
cp -rf $TMP_PATH/dependencies/boot/* /boot/
cp -rf $TMP_PATH/dependencies/etc/* /etc/
cp -rf $TMP_PATH/dependencies/lib/* /lib/
cp -rf $TMP_PATH/dependencies/usr/* /usr/
echo "Dependencies installed successfully."

echo ""
echo "Installing included firmwares..."
cp -rf $TMP_PATH/firmware/* $BOOT_PATH/
echo "Firmwares installed successfully."

if [ -e "/etc/initramfs-tools/initramfs.conf" ]; then
    sed -i "s|MODULES=dep|MODULES=most|g" /etc/initramfs-tools/initramfs.conf
fi
update-initramfs -c -k KERNEL_VERSION

echo ""
echo "Applying boot kernel..."

if [ -e "$BOOT_PATH/kernel_2712.img" ]; then
    echo "Boot kernel applied successfully on $BOOT_PATH/kernel_2712.img"
fi
if [ -e "$BOOT_PATH/vmlinuz" ]; then
    cp -rf "$BOOT_PATH/vmlinuz-KERNEL_VERSION" "$BOOT_PATH/vmlinuz"
    echo "Boot kernel applied successfully on $BOOT_PATH/vmlinuz"
fi
if [ -e "$BOOT_PATH/initrd.img" ]; then
    cp -rf "$BOOT_PATH/initrd.img-KERNEL_VERSION" "$BOOT_PATH/initrd.img"
    echo "Boot Kernel initramfs applied successfully on $BOOT_PATH/initrd.img"
fi

echo ""
echo ""
echo ""
echo "!!! You can get the backup of $BOOT_PATH in $OPT_PATH !!!"
echo "!!! Check your config.txt and cmdline.txt before reboot system. !!!"

rm -rf $TMP_PATH
EOF
sed -i "s|KERNEL_VERSION|$KERNEL_VERSION|g" $MANUAL_OUTPUT/install.sh
sed -i "s|BUILD_VERSION|$BUILD_VERSION|g" $MANUAL_OUTPUT/install.sh

chmod +x $MANUAL_OUTPUT/install.sh

tree -L 2 $MANUAL_OUTPUT

tar -czvf $OUTPUT/novkernel-$KERNEL_VERSION\_$BUILD_VERSION.tar.gz -C $MANUAL_OUTPUT .

############# DEB PACK

DEB_PREBUILT="../prebuilt"

mkdir -p $DEB_PREBUILT/boot/firmware/overlays

dpkg-deb -R ../linux-headers-*.deb $DEB_PREBUILT/
rm -rf $DEB_PREBUILT/DEBIAN
dpkg-deb -R ../linux-libc-*.deb $DEB_PREBUILT/
rm -rf $DEB_PREBUILT/DEBIAN
dpkg-deb -R ../linux-image-*.deb $DEB_PREBUILT/
rm -rf $DEB_PREBUILT/DEBIAN/control

cp $KERNEL_IMAGE $DEB_PREBUILT/boot/firmware/kernel_2712.img
cp $DTB_OVERLAYS/broadcom/*.dtb $DEB_PREBUILT/boot/firmware/
cp $DTB_OVERLAYS/overlays/*.dtbo $DEB_PREBUILT/boot/firmware/overlays/

find $DEB_PREBUILT/boot/firmware/ -type f \( -name "*.dtb" -o -name "*.dtbo" -o -name "*.img" \) | while read file; do
    relative_path=$(realpath --relative-to=$DEB_PREBUILT/boot/firmware/ "$file")
    sed -i "/^set -e/a rm -vf \"\$BOOT_PATH/$relative_path\"" $DEB_PREBUILT/DEBIAN/preinst
done
find $DEB_PREBUILT/boot/firmware/ -type f \( -name "*.dtb" -o -name "*.dtbo" -o -name "*.img" \) | while read file; do
    relative_path=$(realpath --relative-to=$DEB_PREBUILT/boot/firmware/ "$file")
    sed -i "/^set -e/a [ -e \"\$BOOT_PATH/$relative_path\" ] && cp -vf \"\$BOOT_PATH/$relative_path\" \"/boot/firmware.$BUILD_VERSION.bak/$relative_path\"" $DEB_PREBUILT/DEBIAN/preinst
done

sed -i "/^set -e/a mkdir -p /boot/firmware.$BUILD_VERSION.bak/overlays" $DEB_PREBUILT/DEBIAN/preinst
sed -i "/^set -e/a sed -i \"s|MODULES=dep|MODULES=most|g\" /etc/initramfs-tools/initramfs.conf" $DEB_PREBUILT/DEBIAN/preinst
sed -i "/^set -e/a \
BOOT_PATH=\"\"\n\
if [ -e \"/boot/firmware/bootcode.bin\" ]; then\n\
    echo \"'/boot/firmware' found.\"\n\
    BOOT_PATH=\"/boot/firmware\"\n\
elif [ -e \"/boot/bootcode.bin\" ]; then\n\
    echo \"'/boot' found.\"\n\
    BOOT_PATH=\"/boot\"\n\
else \n\
    echo \"There's no supported boot structure found.\"\n\
    exit;\n\
fi\n\
" $DEB_PREBUILT/DEBIAN/preinst

sed -i "/exit 0/i\
BOOT_PATH=\"\"\n\
echo \"Detect boot sturucture...\"\n\
if [ -e \"/boot/firmware/bootcode.bin\" ]; then\n\
    echo \"'/boot/firmware' found.\"\n\
    BOOT_PATH=\"/boot/firmware\"\n\
elif [ -e \"/boot/bootcode.bin\" ]; then\n\
    echo \"'/boot' found.\"\n\
    BOOT_PATH=\"/boot\"\n\
    cp -rf /boot/firmware/* /boot/\n\
fi\n\
if [ -e \"\$BOOT_PATH/kernel_2712.img\" ]; then\n\
    echo \"Boot kernel applied successfully on \$BOOT_PATH/kernel_2712.img\"\n\
fi\n\
if [ -e \"\$BOOT_PATH/vmlinuz\" ]; then\n\
    cp -rf \"\$BOOT_PATH/vmlinuz-$KERNEL_VERSION\" \"\$BOOT_PATH/vmlinuz\"\n\
    echo \"Boot kernel applied successfully on \$BOOT_PATH/vmlinuz\"\n\
fi\n\
if [ -e \"\$BOOT_PATH/initrd.img\" ]; then\n\
    cp -rf \"\$BOOT_PATH/initrd.img-$KERNEL_VERSION\" \"\$BOOT_PATH/initrd.img\"\n\
    echo \"Boot Kernel initramfs applied successfully on \$BOOT_PATH/initrd.img\"\n\
fi\n\
" $DEB_PREBUILT/DEBIAN/postinst

sed -i "/^set -e/a\
if [ \"\$1\" = \"remove\" ]; then\n\
    cp -rvf /boot/firmware.$BUILD_VERSION.bak/* /boot/firmware/\n\
    rm -rvf /boot/firmware.$BUILD_VERSION.bak\n\
fi\n\
" $DEB_PREBUILT/DEBIAN/postrm

cat << 'EOF' > $DEB_PREBUILT/DEBIAN/control
Package: novkernel-KERNEL_VERSION
Source: linux-upstream
Version: BUILD_VERSION
Architecture: arm64
Maintainer: paragonnov <qkdxorjs1002@gmail.com>
Section: kernel
Priority: optional
Replaces: linux-image, linux-kernel-headers, linux-libc-dev, linux-image-rpi-2712, raspberrypi-kernel, clockworkpi-cm-firmware, clockworkpi-kernel
Description: Custom Kernel for uConsole CM5(Lite)
EOF

sed -i "s|KERNEL_VERSION|$KERNEL_VERSION|g" $DEB_PREBUILT/DEBIAN/control
sed -i "s|BUILD_VERSION|$BUILD_VERSION|g" $DEB_PREBUILT/DEBIAN/control

mkdir -p $OUTPUT
dpkg-deb --build $DEB_PREBUILT $OUTPUT/novkernel-$KERNEL_VERSION\_$BUILD_VERSION.deb
