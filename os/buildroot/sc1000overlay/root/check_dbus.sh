#!/bin/sh
# D-Bus diagnostic script
# Run this on the target device to check D-Bus status

echo "=== D-Bus Diagnostic Check ==="
echo ""

echo "1. Checking D-Bus daemon process:"
if pidof dbus-daemon > /dev/null 2>&1; then
    echo "   [OK] dbus-daemon is running (PID: $(pidof dbus-daemon))"
else
    echo "   [FAIL] dbus-daemon is NOT running"
fi
echo ""

echo "2. Checking D-Bus system socket:"
if [ -S /var/run/dbus/system_bus_socket ]; then
    echo "   [OK] System bus socket exists: /var/run/dbus/system_bus_socket"
    ls -l /var/run/dbus/system_bus_socket
else
    echo "   [FAIL] System bus socket NOT found: /var/run/dbus/system_bus_socket"
fi
echo ""

echo "3. Checking D-Bus configuration files:"
if [ -f /etc/dbus-1/system.conf ]; then
    echo "   [OK] System config exists: /etc/dbus-1/system.conf"
else
    echo "   [FAIL] System config NOT found: /etc/dbus-1/system.conf"
fi

if [ -d /usr/share/dbus-1/system-services ]; then
    echo "   [OK] System services directory exists"
    echo "   Services found:"
    ls -1 /usr/share/dbus-1/system-services/ 2>/dev/null | head -5
else
    echo "   [WARN] System services directory NOT found"
fi
echo ""

echo "4. Checking dbus-daemon binary:"
if [ -x /usr/bin/dbus-daemon ]; then
    echo "   [OK] dbus-daemon found at: /usr/bin/dbus-daemon"
    /usr/bin/dbus-daemon --version 2>&1 | head -1
elif [ -x /usr/sbin/dbus-daemon ]; then
    echo "   [OK] dbus-daemon found at: /usr/sbin/dbus-daemon"
    /usr/sbin/dbus-daemon --version 2>&1 | head -1
else
    echo "   [FAIL] dbus-daemon binary NOT found"
fi
echo ""

echo "5. Checking init script:"
if [ -x /etc/init.d/S20dbus ]; then
    echo "   [OK] D-Bus init script exists: /etc/init.d/S20dbus (Buildroot default)"
elif [ -x /etc/init.d/S30dbus ]; then
    echo "   [OK] D-Bus init script exists: /etc/init.d/S30dbus"
else
    echo "   [FAIL] D-Bus init script NOT found"
fi
echo ""

echo "6. Testing D-Bus connection (if dbus-send is available):"
if command -v dbus-send > /dev/null 2>&1; then
    if dbus-send --system --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.GetId 2>/dev/null | grep -q string; then
        echo "   [OK] D-Bus connection test successful"
    else
        echo "   [FAIL] D-Bus connection test failed"
    fi
else
    echo "   [SKIP] dbus-send not available"
fi
echo ""

echo "7. Checking init script execution order:"
echo "   Init scripts in /etc/init.d:"
ls -1 /etc/init.d/S* 2>/dev/null | sort
echo ""

echo "=== Diagnostic Complete ==="

