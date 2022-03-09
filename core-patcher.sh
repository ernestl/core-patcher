#!/bin/bash
#
# core patches, add a snapd deb to the core snap and adjust things
# so that it's exactly as if it was done via a full snap ubild
#
# To use it, one needs the to download the updated debs from
# Launchpad or a private PPA for all the supported architectures
# in the same directory that the tool run from.

set -e

OLD_VER=2.54.2
NEW_VER=2.54.3

if [ "$UID" -ne 0 ]; then
    echo "script must run as root"
    exit 1
fi

for arch in i386 amd64 armhf arm64 ppc64el s390x; do
    echo "patching $arch"

    core_name=core_"${OLD_VER}"_"${arch}"
    core_unpack_dir=core-"${arch}"

    # update core with deb
    UBUNTU_STORE_ARCH="$arch" snap download --basename="${core_name}" --stable core
    if [ ! -d "$core_unpack_dir" ]; then
        unsquashfs -d "$core_unpack_dir" "${core_name}".snap
    fi
    # XXX: should we also unpack ubuntu-core-snapd-units?
    dpkg-deb -x ./snapd_${NEW_VER}_${arch}.deb "${core_unpack_dir}"
    # post-process the deb extraction
    rm "${core_unpack_dir}"/etc/profile.d/apps-bin-path.sh
    rm -rf "${core_unpack_dir}"/usr/share/man/
    gzip -9 -f "${core_unpack_dir}"/usr/share/doc/snapd/copyright
    chmod 0111 "${core_unpack_dir}"/var/lib/snapd/void
    # see core snap: 26-fixup-core.chroot
    rm -f "${core_unpack_dir}"/lib/udev/snappy-app-dev
    cp -a "${core_unpack_dir}"/usr/lib/snapd/snap-device-helper "${core_unpack_dir}"/lib/udev/snappy-app-dev

    # update manifests
    sed -i "s/snapd=$OLD_VER/snapd=$NEW_VER/" "$core_unpack_dir"/usr/share/snappy/dpkg.yaml
    sed -i "s/ubuntu-core-snapd-units=$OLD_VER/ubuntu-core-snapd-units=$NEW_VER/" "$core_unpack_dir"/usr/share/snappy/dpkg.yaml
    grep -q  "snapd=$NEW_VER" "$core_unpack_dir"/usr/share/snappy/dpkg.yaml
    grep -q "ubuntu-core-snapd-units=$NEW_VER" "$core_unpack_dir"/usr/share/snappy/dpkg.yaml

    sed -i "s/snapd=$OLD_VER/snapd=$NEW_VER/" "$core_unpack_dir"/snap/manifest.yaml
    grep -q "snapd=$NEW_VER" "$core_unpack_dir"/snap/manifest.yaml
    
    # XXX: OLD_VER must be regex friendly, i.e. "+" will break things
    sed -i -E  "s/^(ii\ + snapd .*) ${OLD_VER} (.*)/\1 ${NEW_VER} \2/" "$core_unpack_dir"/usr/share/snappy/dpkg.list
    sed -i -E  "s/^(ii\ + ubuntu-core-snapd-units .*) ${OLD_VER} (.*)/\1 ${NEW_VER} \2/" "$core_unpack_dir"/usr/share/snappy/dpkg.list
    grep -q -E  "^ii\ +snapd\ + $NEW_VER " "$core_unpack_dir"/usr/share/snappy/dpkg.list
    grep -q -E "^ii\ +ubuntu-core-snapd-units\ + $NEW_VER " "$core_unpack_dir"/usr/share/snappy/dpkg.list

    # replace meta/snap.yaml version
    sed -i s/"$OLD_VER"/"$NEW_VER"/ "$core_unpack_dir"/meta/snap.yaml

    # ensure no old version is left
    if grep -r $(echo "$OLD_VER" | sed 's/\./\\./g') "$core_unpack_dir"; then
        echo "found old version"
        exit 1
    fi
    
    (cd "$core_unpack_dir" ; snap pack --filename="../core_${NEW_VER}_${arch}".snap)

    # test if filelist/permissions/link targets are identical
    if ! diff -u \
         <(unsquashfs -n -ll "core_${OLD_VER}_${arch}.snap"|awk '{print $1" "$2" "$6" "$7" "$8}') \
         <(unsquashfs -n -ll "core_${NEW_VER}_${arch}.snap"|awk '{print $1" "$2" "$6" "$7" "$8}'); then
        echo "ERROR unexpected diff"
        exit 1
    fi

done
            
