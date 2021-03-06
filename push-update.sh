#!/bin/sh

updates_dir=/data/candy_updates

if [ ! -f "$1" ]; then
    echo "Usage: $0 ZIP [UNVERIFIED]"
    echo "Push ZIP to $updates_dir and add it to Updater"
    echo
    echo "The name of ZIP should have this format: Candy-BUILD-VERSION-version-TYPE-DATE-TIME"
    echo
    echo "If UNVERIFIED is set, the app will verify the update"
    exit
fi
zip_path=`realpath "$1"`

if [ "`adb get-state 2>/dev/null`" != "device" ]; then
    echo "No device found. Waiting for one..."
    adb wait-for-device
fi
uid=$(adb shell id -u)
if [ "$uid" -ne 0 ]; then
    if ! adb root; then
        echo "Could not run adbd as root"
        exit 1
    fi
    did_root=1
else
    did_root=0
fi

zip_path_device=$updates_dir/`basename "$zip_path"`
if adb shell test -f "$zip_path_device"; then
    echo "$zip_path_device exists already"
    exit 1
fi

if [ -n "$2" ]; then
    status=1
else
    status=2
fi


# Candy-BUILD-VERSION-TYPE-DATE-TIME.zip
# Candy-sunfish-11.0-OFFICIAL-20200507-1158.zip
#  f1    f2      f3    f4        f5     f6
#
zip_name=`basename "$zip_path"`
id=`echo "$zip_name" | sha1sum | cut -d' ' -f1`
version=`echo "$zip_name" | cut -d'-' -f3`
type=`echo "$zip_name" | cut -d'-' -f4`
build_date=`echo "$zip_name" | cut -d'-' -f5`
timestamp=`date --date="$build_date 23:59:59" +%s`
size=`stat -c "%s" "$zip_path"`

adb push "$zip_path" "$zip_path_device"
adb shell chgrp cache "$zip_path_device"
adb shell chmod 664 "$zip_path_device"

# Kill the app before updating the database
adb shell "killall org.candy.updater 2>/dev/null"
adb shell "sqlite3 /data/data/org.candy.updater/databases/updates.db" \
    "\"INSERT INTO updates (status, path, download_id, timestamp, type, version, size)" \
    "  VALUES ($status, '$zip_path_device', '$id', $timestamp, '$type', '$version', $size)\""

if [ "$did_root" -ne 0 ]; then
    # Exit root mode
    adb unroot
fi
