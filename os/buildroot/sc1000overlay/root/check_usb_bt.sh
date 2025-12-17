#!/bin/sh
# Quick USB Bluetooth dongle detection script
# Run this after inserting USB Bluetooth dongle

echo "=== USB Bluetooth Dongle Quick Check ==="
echo ""

echo "1. Checking USB device detection (last 20 lines of dmesg):"
echo "   Looking for USB and Bluetooth related messages..."
dmesg | tail -20 | grep -i "usb\|bluetooth\|hci\|btusb" || echo "   (No recent USB/Bluetooth messages)"
echo ""

echo "2. Checking for HCI devices:"
if [ -d /sys/class/bluetooth ]; then
    hci_devices=$(ls -1 /sys/class/bluetooth/ 2>/dev/null | grep hci || true)
    if [ -n "$hci_devices" ]; then
        echo "   [OK] HCI device(s) found:"
        echo "$hci_devices" | while read device; do
            echo "      - $device"
            if [ -f /sys/class/bluetooth/$device/address ]; then
                addr=$(cat /sys/class/bluetooth/$device/address 2>/dev/null)
                echo "        MAC Address: $addr"
            fi
            if [ -f /sys/class/bluetooth/$device/name ]; then
                name=$(cat /sys/class/bluetooth/$device/name 2>/dev/null)
                echo "        Name: $name"
            fi
        done
    else
        echo "   [FAIL] No HCI devices found"
        echo "   USB dongle may not be detected yet"
    fi
else
    echo "   [FAIL] /sys/class/bluetooth/ does not exist"
fi
echo ""

echo "3. Checking USB devices (Bluetooth-related):"
if [ -d /sys/bus/usb/devices ]; then
    found=0
    for usb_dev in /sys/bus/usb/devices/*; do
        if [ -f "$usb_dev/idVendor" ] && [ -f "$usb_dev/idProduct" ]; then
            vendor=$(cat "$usb_dev/idVendor" 2>/dev/null)
            product=$(cat "$usb_dev/idProduct" 2>/dev/null)
            # Common Bluetooth vendor IDs
            case "$vendor" in
                0a12|0b05|0489|04ca|0e8d|13d3|048d|0cf3|04e8|0930|0bda|2357|2a03|8087|0a5c|05ac)
                    if [ -f "$usb_dev/product" ]; then
                        product_name=$(cat "$usb_dev/product" 2>/dev/null)
                        echo "   [FOUND] Bluetooth USB device:"
                        echo "      Vendor: $vendor, Product: $product"
                        echo "      Name: $product_name"
                        found=1
                    else
                        echo "   [FOUND] Possible Bluetooth USB device:"
                        echo "      Vendor: $vendor, Product: $product"
                        found=1
                    fi
                    ;;
            esac
        fi
    done
    if [ $found -eq 0 ]; then
        echo "   [INFO] No obvious Bluetooth USB devices found in /sys/bus/usb/devices"
        echo "   Try: dmesg | grep -i usb | tail -10"
    fi
else
    echo "   [WARN] Cannot check USB devices"
fi
echo ""

echo "4. Checking bluetoothd status:"
if pidof bluetoothd > /dev/null 2>&1; then
    echo "   [OK] bluetoothd is running (PID: $(pidof bluetoothd))"
    echo "   Note: If HCI device was just inserted, bluetoothd may need a moment to detect it"
    echo "   Or you may need to restart bluetoothd: /etc/init.d/S31bluetooth restart"
else
    echo "   [WARN] bluetoothd is not running"
    echo "   Start it with: /etc/init.d/S31bluetooth start"
fi
echo ""

echo "5. Quick test commands:"
echo "   - Check dmesg for USB detection: dmesg | tail -30"
echo "   - List HCI devices: ls -la /sys/class/bluetooth/"
echo "   - Check if btusb module is loaded: ls -d /sys/module/btusb"
echo "   - Restart bluetoothd: /etc/init.d/S31bluetooth restart"
echo "   - Full diagnostic: ./check_bluetooth.sh"
echo ""

echo "=== Quick Check Complete ==="

