#!/bin/bash
# Compare original and newly built sdcard images

ORIGINAL_IMG_GZ="/Users/koji/work/SC1000/os/sdcard.img.gz"
ORIGINAL_IMG="/tmp/orig_sdcard.img"
NEW_IMG="/tmp/new_sdcard.img"

echo "=== Extracting original sdcard.img from gz ==="
gunzip -c "$ORIGINAL_IMG_GZ" > "$ORIGINAL_IMG" 2>/dev/null || {
    echo "Error: Failed to extract original image from $ORIGINAL_IMG_GZ"
    exit 1
}

echo "=== Extracting new sdcard.img from Docker volume ==="
docker run --rm -v sc1000_buildroot-output:/work/buildroot-output -v /tmp:/tmp --entrypoint /bin/bash sc1000-sc1000-dev -c "cp /work/buildroot-output/images/sdcard.img /tmp/new_sdcard.img && ls -lh /tmp/new_sdcard.img" 2>/dev/null || echo "Image copy failed"

if [ ! -f "$NEW_IMG" ]; then
    echo "New image not found. Build may still be in progress."
    rm -f "$ORIGINAL_IMG"
    exit 1
fi

echo ""
echo "=== Comparing U-Boot sections ==="
echo "--- Original U-Boot (offset 8192) ---"
dd if="$ORIGINAL_IMG" bs=1 skip=8192 count=500000 2>/dev/null | strings | grep -i "olinuxino" | head -10

echo ""
echo "--- New U-Boot (offset 8192) ---"
dd if="$NEW_IMG" bs=1 skip=8192 count=500000 2>/dev/null | strings | grep -i "olinuxino" | head -10

echo ""
echo "=== Comparing boot partition files ==="
echo "--- Original boot.scr ---"
hdiutil attach "$ORIGINAL_IMG" -mountpoint /tmp/orig_boot 2>&1 | grep -v "hdiutil" || true
strings /tmp/orig_boot/boot.scr 2>/dev/null | grep -v "^V!M8"
ls -la /tmp/orig_boot/*.dtb 2>/dev/null
hdiutil detach /tmp/orig_boot 2>/dev/null || true

echo ""
echo "--- New boot.scr ---"
hdiutil attach "$NEW_IMG" -mountpoint /tmp/new_boot 2>&1 | grep -v "hdiutil" || true
strings /tmp/new_boot/boot.scr 2>/dev/null | grep -v "^V!M8"
ls -la /tmp/new_boot/*.dtb 2>/dev/null
hdiutil detach /tmp/new_boot 2>/dev/null || true

echo ""
echo "=== Comparing DTB files ==="
ORIG_DTB=$(hdiutil attach "$ORIGINAL_IMG" -mountpoint /tmp/orig_boot2 2>&1 | grep FAT | awk '{print $1}' | head -1)
if [ -n "$ORIG_DTB" ]; then
    mount -t msdos "$ORIG_DTB" /tmp/orig_boot2 2>/dev/null || true
    echo "--- Original DTB ---"
    strings /tmp/orig_boot2/*.dtb 2>/dev/null | head -5
    umount /tmp/orig_boot2 2>/dev/null || true
    hdiutil detach "$ORIG_DTB" 2>/dev/null || true
fi

NEW_DTB=$(hdiutil attach "$NEW_IMG" -mountpoint /tmp/new_boot2 2>&1 | grep FAT | awk '{print $1}' | head -1)
if [ -n "$NEW_DTB" ]; then
    mount -t msdos "$NEW_DTB" /tmp/new_boot2 2>/dev/null || true
    echo "--- New DTB ---"
    strings /tmp/new_boot2/*.dtb 2>/dev/null | head -5
    umount /tmp/new_boot2 2>/dev/null || true
    hdiutil detach "$NEW_DTB" 2>/dev/null || true
fi

echo ""
echo "=== Summary ==="
echo "Original image (from gz) size: $(ls -lh "$ORIGINAL_IMG" | awk '{print $5}')"
echo "New image size: $(ls -lh "$NEW_IMG" | awk '{print $5}')"

# Cleanup
rm -f "$ORIGINAL_IMG"

