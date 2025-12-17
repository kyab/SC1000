#!/bin/sh
# Bluetooth diagnostic script
# Run this on the target device to check Bluetooth status

echo "=== Bluetooth Diagnostic Check ==="
echo ""

echo "1. Checking bluetoothd process:"
if pidof bluetoothd > /dev/null 2>&1; then
    echo "   [OK] bluetoothd is running (PID: $(pidof bluetoothd))"
else
    echo "   [FAIL] bluetoothd is NOT running"
fi
echo ""

echo "2. Checking bluetoothd binary:"
if [ -x /usr/libexec/bluetooth/bluetoothd ]; then
    echo "   [OK] bluetoothd found at: /usr/libexec/bluetooth/bluetoothd"
    /usr/libexec/bluetooth/bluetoothd --version 2>&1 | head -1
elif [ -x /usr/sbin/bluetoothd ]; then
    echo "   [OK] bluetoothd found at: /usr/sbin/bluetoothd"
    /usr/sbin/bluetoothd --version 2>&1 | head -1
else
    echo "   [FAIL] bluetoothd binary NOT found"
fi
echo ""

echo "3. Checking for Bluetooth hardware (HCI devices):"
if [ -d /sys/class/bluetooth ]; then
    hci_devices=$(ls -1 /sys/class/bluetooth/ 2>/dev/null | grep hci || true)
    if [ -n "$hci_devices" ]; then
        hci_count=$(echo "$hci_devices" | wc -l)
        echo "   [OK] Found $hci_count HCI device(s):"
        echo "$hci_devices" | while read device; do
            echo "      - $device"
        done
    else
        echo "   [FAIL] No HCI devices found in /sys/class/bluetooth/"
        echo "   This indicates no Bluetooth hardware is present or kernel modules are not loaded"
    fi
else
    echo "   [FAIL] /sys/class/bluetooth/ directory does not exist"
    echo "   Bluetooth kernel support may not be enabled"
fi
echo ""

echo "3a. Checking USB devices for Bluetooth adapters:"
if [ -d /sys/bus/usb/devices ]; then
    usb_bt_found=0
    for usb_dev in /sys/bus/usb/devices/*/idVendor; do
        if [ -f "$usb_dev" ] && [ -f "${usb_dev%idVendor}idProduct" ]; then
            vendor=$(cat "$usb_dev" 2>/dev/null)
            product=$(cat "${usb_dev%idVendor}idProduct" 2>/dev/null)
            # Check if this might be a Bluetooth device (common Bluetooth vendor IDs)
            # 0a12 = Cambridge Silicon Radio (CSR)
            # 0b05 = ASUSTek Computer Inc.
            # 0489 = Foxconn / Hon Hai
            # 04ca = Lite-On Technology Corp
            # 0e8d = MediaTek Inc.
            # 13d3 = IMC Networks
            # 048d = Integrated Technology Express, Inc.
            case "$vendor" in
                0a12|0b05|0489|04ca|0e8d|13d3|048d|*)
                    # Check product name or class
                    if [ -f "${usb_dev%idVendor}../bInterfaceClass" ]; then
                        class=$(cat "${usb_dev%idVendor}../bInterfaceClass" 2>/dev/null)
                        if [ "$class" = "e0" ] || [ "$class" = "ff" ]; then
                            echo "   [INFO] Possible Bluetooth USB device found:"
                            echo "      Vendor: $vendor, Product: $product"
                            usb_bt_found=1
                        fi
                    fi
                    ;;
            esac
        fi
    done
    if [ $usb_bt_found -eq 0 ]; then
        echo "   [WARN] No obvious Bluetooth USB devices detected"
        echo "   Note: USB Bluetooth dongle may not be connected or not recognized"
    fi
else
    echo "   [WARN] Cannot check USB devices (/sys/bus/usb/devices not accessible)"
fi
echo ""

echo "3b. Checking RFKILL status:"
if [ -d /sys/class/rfkill ]; then
    rfkill_devices=$(ls -1 /sys/class/rfkill/ 2>/dev/null | wc -l)
    if [ "$rfkill_devices" -gt 0 ]; then
        echo "   [OK] Found $rfkill_devices RFKILL device(s):"
        for rfkill in /sys/class/rfkill/rfkill*; do
            if [ -f "$rfkill/name" ] && [ -f "$rfkill/type" ] && [ -f "$rfkill/state" ]; then
                name=$(cat "$rfkill/name" 2>/dev/null)
                type=$(cat "$rfkill/type" 2>/dev/null)
                state=$(cat "$rfkill/state" 2>/dev/null)
                if [ "$type" = "bluetooth" ]; then
                    if [ "$state" = "0" ]; then
                        echo "      - $name: UNBLOCKED (type: $type)"
                    else
                        echo "      - $name: BLOCKED (type: $type) - Bluetooth may be disabled"
                    fi
                fi
            fi
        done
    else
        echo "   [INFO] No RFKILL devices found (this is normal if RFKILL is not configured)"
    fi
else
    echo "   [WARN] /sys/class/rfkill/ directory does not exist"
    echo "   RFKILL support may not be enabled in kernel"
fi
echo ""

echo "4. Checking for Bluetooth kernel modules:"
if [ -d /sys/module ]; then
    if ls -d /sys/module/bluetooth 2>/dev/null > /dev/null; then
        echo "   [OK] Bluetooth kernel module is loaded"
    else
        echo "   [WARN] Bluetooth kernel module not loaded"
        echo "   Try: modprobe bluetooth"
    fi
    
    if ls -d /sys/module/btusb 2>/dev/null > /dev/null; then
        echo "   [OK] btusb (USB Bluetooth) kernel module is loaded"
    elif ls -d /sys/module/btuart 2>/dev/null > /dev/null; then
        echo "   [OK] btuart (UART Bluetooth) kernel module is loaded"
    else
        echo "   [INFO] No Bluetooth transport module loaded (btusb/btuart)"
    fi
else
    echo "   [WARN] Cannot check kernel modules (/sys/module not accessible)"
fi
echo ""

echo "6. Checking bluetoothd error logs:"
if [ -f /var/log/messages ]; then
    echo "   Recent bluetoothd errors from syslog:"
    errors=$(grep -i "bluetoothd.*error\|bluetoothd.*fail\|Failed to access\|Adapter handling\|RFKILL" /var/log/messages 2>/dev/null | tail -5)
    if [ -n "$errors" ]; then
        echo "$errors"
    else
        echo "   (No recent errors found)"
    fi
elif command -v dmesg > /dev/null 2>&1; then
    echo "   Recent Bluetooth-related messages from dmesg:"
    bt_msgs=$(dmesg | grep -i "bluetooth\|hci\|btusb" | tail -10)
    if [ -n "$bt_msgs" ]; then
        echo "$bt_msgs"
    else
        echo "   (No recent Bluetooth messages found)"
    fi
else
    echo "   [WARN] Cannot access log files"
fi
echo ""

echo "7. Testing bluetoothd startup (if not running):"
if ! pidof bluetoothd > /dev/null 2>&1; then
    echo "   Attempting to start bluetoothd manually to see error messages..."
    if [ -x /usr/libexec/bluetooth/bluetoothd ]; then
        /usr/libexec/bluetooth/bluetoothd --debug 2>&1 | head -10 &
        sleep 2
        if pidof bluetoothd > /dev/null 2>&1; then
            echo "   [OK] bluetoothd started successfully"
            killall bluetoothd 2>/dev/null
        else
            echo "   [FAIL] bluetoothd failed to start (see errors above)"
        fi
    fi
else
    echo "   [SKIP] bluetoothd is already running"
fi
echo ""

echo "8. Common error messages and their meanings:"
echo "   - 'Failed to access management interface': No HCI device available"
echo "   - 'Adapter handling initialization failed': Hardware not found or not accessible"
echo "   - 'No HCI device available': Bluetooth hardware not present or kernel module not loaded"
echo "   - 'Failed to open RFKILL control device': RFKILL interface not available (may be normal)"
echo ""

echo "9. Recommendations:"
if [ ! -d /sys/class/bluetooth ] || [ -z "$(ls -1 /sys/class/bluetooth/ 2>/dev/null | grep hci)" ]; then
    echo "   [ACTION REQUIRED] No HCI device found. Try:"
    echo "   1. Ensure USB Bluetooth dongle is physically connected"
    echo "   2. Check USB connection: lsusb (if available) or check /sys/bus/usb/devices"
    echo "   3. Verify USB port is working (try another USB device)"
    echo "   4. Check dmesg for USB device detection: dmesg | grep -i usb"
    echo "   5. Try manually loading btusb: modprobe btusb"
    echo "   6. Check if device needs firmware: dmesg | grep -i firmware"
fi
echo ""

echo "=== Diagnostic Complete ==="


