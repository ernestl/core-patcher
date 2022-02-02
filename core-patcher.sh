#!/bin/sh

set -ex

OLD_VER=2.54.2
NEW_VER=2.54.3

if [ $UID -ne 0 ]; then
    echo "script must run as root"
    exit 1
fi

for arch in i386; do
    core_name=core_"${OLD_VER}"_"${arch}"
    core_unpack_dir=core-"${arch}"

    # update core with deb
    UBUNTU_STORE_ARCH="$arch" snap download --basename="${core_name}" --stable core
    if [ ! -d "$core_unpack_dir" ]; then
        unsquashfs -d "$core_unpack_dir" "${core_name}".snap
    fi
    # XXX: should we also unpack ubuntu-core-snapd-units?
    dpkg-deb -x ./snapd_${NEW_VER}_${arch}.deb "${core_unpack_dir}"
    # update manifests
    sed -i "s/snapd=$OLD_VER/snapd=$NEW_VER/" "$core_unpack_dir"/usr/share/snappy/dpkg.yaml
    sed -i "s/ubuntu-core-snapd-units=$OLD_VER/ubuntu-core-snapd-units=$NEW_VER/" "$core_unpack_dir"/usr/share/snappy/dpkg.yaml
    grep  "snapd=$NEW_VER" "$core_unpack_dir"/usr/share/snappy/dpkg.yaml
    grep  "ubuntu-core-snapd-units=$NEW_VER" "$core_unpack_dir"/usr/share/snappy/dpkg.yaml

    sed -i "s/snapd=$OLD_VER/snapd=$NEW_VER/" "$core_unpack_dir"/snap/manifest.yaml
    grep  "snapd=$NEW_VER" "$core_unpack_dir"/snap/manifest.yaml
    
    
    # XXX: OLD_VER must be regex friendly, i.e. "+" will break things
    sed -i -E  "s/^(ii\ + snapd .*) ${OLD_VER} (.*)/\1 ${NEW_VER} \2/" "$core_unpack_dir"/usr/share/snappy/dpkg.list
    sed -i -E  "s/^(ii\ + ubuntu-core-snapd-units .*) ${OLD_VER} (.*)/\1 ${NEW_VER} \2/" "$core_unpack_dir"/usr/share/snappy/dpkg.list
    grep -E  "^ii\ +snapd\ + $NEW_VER " "$core_unpack_dir"/usr/share/snappy/dpkg.list
    grep -E "^ii\ +ubuntu-core-snapd-units\ + $NEW_VER " "$core_unpack_dir"/usr/share/snappy/dpkg.list

    # replace meta/snap.yaml version
    sed -i s/"$OLD_VER"/"$NEW_VER"/ "$core_unpack_dir"/meta/snap.yaml

    # ensure no old version is left
    if grep -r $(echo "$OLD_VER" | sed 's/\./\\./g') "$core_unpack_dir"; then
        echo "found old version"
        exit 1
    fi
    
    (cd "$core_unpack_dir" ; snap pack)

done
            
