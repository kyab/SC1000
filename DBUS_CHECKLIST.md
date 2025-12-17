# D-Bus Diagnostic Checklist

This document provides a step-by-step checklist to verify D-Bus is working correctly on the SC1000 system.

## Files Created/Modified

1. **`/etc/init.d/S20dbus`** - D-Bus startup script (runs before S30bluetooth)
2. **`/root/check_dbus.sh`** - Diagnostic script to check D-Bus status
3. **`/etc/init.d/S30bluetooth`** - Modified to wait for D-Bus before starting

## Step-by-Step Verification

### Step 1: Rebuild the Image

```bash
cd /Users/koji/work/SC1000
docker compose run --rm sc1000-dev build
```

### Step 2: Write to SD Card

```bash
cd os
# Find your SD card device
diskutil list
# Unmount and write
diskutil unmountDisk /dev/diskXX
sudo dd if=sdcard.img of=/dev/rdiskXX bs=1m status=progress
diskutil eject /dev/diskXX
```

### Step 3: Boot and Check Init Script Order

After boot, check that init scripts are in the correct order:

```bash
ls -1 /etc/init.d/S* | sort
```

Expected order:
- `S20dbus` (D-Bus - must be first)
- `S30bluetooth` (Bluetooth daemon)
- `S40bluealsa` (BlueZ-ALSA)
- `S50xwax` (XWAX application)

### Step 4: Run Diagnostic Script

```bash
/root/check_dbus.sh
```

This will check:
- D-Bus daemon process
- System bus socket
- Configuration files
- Binary location
- Init script
- Connection test

### Step 5: Manual Checks

#### Check D-Bus Process

```bash
pidof dbus-daemon
```

Should return a PID if running.

#### Check D-Bus Socket

```bash
ls -l /var/run/dbus/system_bus_socket
```

Should show a socket file.

#### Check D-Bus Logs

Look for D-Bus messages in console output:
- `Starting system message bus: done.` - Good
- `D-Bus setup failed` - Problem
- `Warning: D-Bus socket not created` - Problem

### Step 6: Test Bluetooth Startup

After D-Bus is confirmed working:

```bash
pidof bluetoothd
```

Should return a PID if bluetoothd started successfully.

## Troubleshooting

### If D-Bus fails to start:

1. Check if dbus-daemon binary exists:
   ```bash
   which dbus-daemon
   ls -l /usr/bin/dbus-daemon /usr/sbin/dbus-daemon
   ```

2. Check D-Bus configuration:
   ```bash
   ls -l /etc/dbus-1/system.conf
   ```

3. Try starting D-Bus manually:
   ```bash
   /etc/init.d/S20dbus start
   ```

4. Check for error messages:
   ```bash
   dmesg | grep -i dbus
   ```

### If bluetoothd still fails:

1. Verify D-Bus is running first:
   ```bash
   pidof dbus-daemon
   ls -l /var/run/dbus/system_bus_socket
   ```

2. Check bluetoothd binary:
   ```bash
   ls -l /usr/libexec/bluetooth/bluetoothd
   ```

3. Try starting bluetoothd manually:
   ```bash
   /usr/libexec/bluetooth/bluetoothd --debug &
   ```

4. Check for error messages:
   ```bash
   dmesg | grep -i bluetooth
   ```

## Expected Boot Sequence

1. System boots
2. `S20dbus` starts D-Bus daemon
3. D-Bus socket created at `/var/run/dbus/system_bus_socket`
4. `S30bluetooth` waits for D-Bus, then starts bluetoothd
5. `S40bluealsa` waits for bluetoothd, then starts bluealsa
6. `S50xwax` starts the application

## Notes

- D-Bus must start before any service that depends on it
- The init script numbering (S20, S30, S40, S50) ensures correct startup order
- Buildroot's D-Bus package should install configuration files automatically
- If configuration files are missing, D-Bus may still work with defaults


