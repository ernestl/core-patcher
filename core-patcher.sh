#!/bin/sh

set -e

OLD_VER=2.53.2
NEW_VER=2.53.3

for arch in i386; do
    core_name=core_"${OLD_VER}"_"${ARCH}".snap
    core_unpack_dir=core-"${arch}"

    # update core with deb
    UBUNTU_STORE_ARCH="$arch" snap download --basename="${core_name}" --stable core
    sudo unsquahfs -d "$core_unpack_dir" "${core_name}"
    dpkg-deb -x ./snapd_${OLD_VER}_${arch}.deb "${core_unpack_dir}"
    # update manifests
    sed -i "s/snapd=$OLD_VER/snapd=$NEW_VER" "$core_unpack_dir"/usr/share/snappy/dpkg.yaml
    sed -i "s/ubuntu-core-snapd-units=$OLD_VER/ubuntu-core-snapd-units=$NEW_VER" "$core_unpack_dir"/usr/share/snappy/dpkg.yaml
    grep  "snapd=$NEW_VER" "$core_unpack_dir"/usr/share/snappy/dpkg.yaml
    grep  "ubuntu-core-snapd-units=$NEW_VER" "$core_unpack_dir"/usr/share/snappy/dpkg.yaml
    
    # XXX: OLD_VER must be regex friendly, i.e. "+" will break things
    sed -i -E  "s/^(ii\ + snapd .*) ${OLD_VER} (.*)/\1 ${NEW_VER} \2/" "$core_unpack_dir"/usr/share/snappy/dpkg.lst
    sed -i -E  "s/^(ii\ + ubuntu-core-snapd-units .*) ${OLD_VER} (.*)/\1 ${NEW_VER} \2/" "$core_unpack_dir"/usr/share/snappy/dpkg.lst
    grep  "^ii\ +snapd\ + $NEW_VER " "$core_unpack_dir"/usr/share/snappy/dpkg.lst
    grep  "^ii\ +ubuntu-core-snapd-units\ + $NEW_VER " "$core_unpack_dir"/usr/share/snappy/dpkg.lst

    # replace meta/snap.yaml version
    sed -i s/"$OLD_VER"/"$NEW_VER"/ "$core_unpack_dir"/meta/snap.yaml

    # ensure no old version is left
    if grep -r "$OLD_VER" "$core_unpack_dir"; then
        echo "found old version"
        exit 1
    fi
    
    (cd core_unpack_dir ; sudo snap pack)

done
            
