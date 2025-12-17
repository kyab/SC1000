#!/bin/sh
# USB device detection diagnostic script
# Run this to check if USB Bluetooth dongle is detected by the kernel

echo "=== USB Device Detection Diagnostic ==="
echo ""

echo "1. Checking all USB devices currently connected:"
if [ -d /sys/bus/usb/devices ]; then
    echo "   USB devices found in /sys/bus/usb/devices:"
    for usb_dev in /sys/bus/usb/devices/*; do
        if [ -f "$usb_dev/idVendor" ] && [ -f "$usb_dev/idProduct" ]; then
            vendor=$(cat "$usb_dev/idVendor" 2>/dev/null)
            product=$(cat "$usb_dev/idProduct" 2>/dev/null)
            dev_path=$(basename "$usb_dev")
            if [ -f "$usb_dev/product" ]; then
                product_name=$(cat "$usb_dev/product" 2>/dev/null)
                echo "      $dev_path: Vendor=$vendor Product=$product ($product_name)"
            else
                echo "      $dev_path: Vendor=$vendor Product=$product"
            fi
        fi
    done
else
    echo "   [ERROR] /sys/bus/usb/devices does not exist"
fi
echo ""

echo "2. Recent USB device detection messages from dmesg:"
dmesg | grep -i "usb.*new\|usb.*device\|usb.*attach" | tail -20 || echo "   (No recent USB detection messages)"
echo ""

echo "3. Checking for Bluetooth-specific USB devices:"
if [ -d /sys/bus/usb/devices ]; then
    found_bt=0
    for usb_dev in /sys/bus/usb/devices/*; do
        if [ -f "$usb_dev/idVendor" ] && [ -f "$usb_dev/idProduct" ]; then
            vendor=$(cat "$usb_dev/idVendor" 2>/dev/null)
            product=$(cat "$usb_dev/idProduct" 2>/dev/null)
            dev_path=$(basename "$usb_dev")
            
            # Check if this is a known Bluetooth vendor ID
            case "$vendor" in
                0a12|0b05|0489|04ca|0e8d|13d3|048d|0cf3|04e8|0930|0bda|2357|2a03|8087|0a5c|05ac|0bda|04f2|0a5c|0e0f|046d|04ca|0bda|0e8d|13d3|0489|0a12|0b05|04ca|0e8d|13d3|048d|0cf3|04e8|0930|0bda|2357|2a03|8087|0a5c|05ac)
                    found_bt=1
                    echo "   [FOUND] Possible Bluetooth device:"
                    echo "      Device: $dev_path"
                    echo "      Vendor ID: $vendor"
                    echo "      Product ID: $product"
                    if [ -f "$usb_dev/product" ]; then
                        product_name=$(cat "$usb_dev/product" 2>/dev/null)
                        echo "      Name: $product_name"
                    fi
                    # Check interface class
                    for iface in "$usb_dev"/*/bInterfaceClass; do
                        if [ -f "$iface" ]; then
                            class=$(cat "$iface" 2>/dev/null)
                            echo "      Interface Class: $class (e0=Wireless Controller, ff=Vendor Specific)"
                        fi
                    done
                    ;;
            esac
        fi
    done
    if [ $found_bt -eq 0 ]; then
        echo "   [WARN] No Bluetooth USB devices found"
        echo "   This could mean:"
        echo "   1. USB Bluetooth dongle is not connected"
        echo "   2. USB port is not working"
        echo "   3. Dongle is not recognized by kernel"
    fi
else
    echo "   [ERROR] Cannot check USB devices"
fi
echo ""

echo "4. Checking btusb module status:"
if [ -d /sys/module/btusb ]; then
    echo "   [OK] btusb module is loaded"
    echo "   Module path: /sys/module/btusb"
    if [ -f /sys/module/btusb/parameters/disable_scofix ]; then
        echo "   Module parameters available"
    fi
else
    echo "   [WARN] btusb module is not loaded"
    echo "   Try: modprobe btusb"
fi
echo ""

echo "5. Checking for HCI devices:"
if [ -d /sys/class/bluetooth ]; then
    hci_list=$(ls -1 /sys/class/bluetooth/ 2>/dev/null | grep hci || true)
    if [ -n "$hci_list" ]; then
        echo "   [OK] HCI devices found:"
        echo "$hci_list" | while read device; do
            echo "      - $device"
        done
    else
        echo "   [FAIL] No HCI devices found"
        echo "   This means USB Bluetooth dongle was not recognized by btusb driver"
    fi
else
    echo "   [FAIL] /sys/class/bluetooth/ does not exist"
fi
echo ""

echo "6. Recommendations:"
echo "   If USB Bluetooth dongle is connected but not detected:"
echo "   1. Check physical connection (try another USB port)"
echo "   2. Check dmesg for USB errors: dmesg | grep -i 'usb.*error\|usb.*fail'"
echo "   3. Try unplugging and replugging the dongle"
echo "   4. Check if dongle needs firmware: dmesg | grep -i firmware"
echo "   5. Try manually reloading btusb: modprobe -r btusb && modprobe btusb"
echo "   6. Check USB power: Some dongles need more power than others"
echo ""

echo "=== Diagnostic Complete ==="

