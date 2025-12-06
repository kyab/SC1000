#!/bin/sh
cd /work/SC1000/updater/tarball
rm -f /work/SC1000/updater/sc.tar
cp /work/SC1000/software/xwax .
cp /work/SC1000/software/scsettings.txt .
cp /work/SC1000/software/scsettings.txt ../
tar -cf /work/SC1000/updater/sc.tar *
#cp /root/SC1000/updater/xwax "/media/root/5A07-BBBC"
#cp /root/SC1000/updater/sc.tar "/media/root/5A07-BBBC"
#cp /root/SC1000/software/scsettings.txt "/media/root/SC1000STICK"
