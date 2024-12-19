#!/usr/bin/bash

# this script enables block-level synchronization of the system disk
# (SSD#1 0x11111111) to the backup system disk (SSD#2 0x222222).
#
# the first two partitions (ESP/Linux) MUST have the same size.
#
# Disk /dev/sda: 465.76 GiB, 500107862016 bytes, 976773168 sectors
# Disk model: Portable SSD
# Units: sectors of 1 * 512 = 512 bytes
# Sector size (logical/physical): 512 bytes / 512 bytes
# I/O size (minimum/optimal): 512 bytes / 33553920 bytes
# Disklabel type: dos
# Disk identifier: 0x11111111
# Device     Boot     Start       End   Sectors  Size Id Type
# /dev/sda1  *         2048    264191    262144  128M ef EFI (FAT-12/16/32)
# /dev/sda2          264192 268699647 268435456  128G 83 Linux
# /dev/sda3       268699648 369362943 100663296   48G  7 HPFS/NTFS/exFAT
# /dev/sda4       369362944 906217979 536855036  256G 83 Linux
#
# Disk /dev/sdb : 223,57 GiB, 240057409536 bytes, 468862128 sectors
# Disk model: SABRENT         
# Units: sectors of 1 × 512 = 512 bytes
# Sector size (logical/physical): 512 bytes / 512 bytes
# I/O size (minimum/optimal): 4096 bytes / 4096 bytes
# Disklabel type : dos
# Disk identifier : 0x22222222
# Device     Boot     Start       End   Sectors  Size Id Type
# /dev/sdb1  *         2048    264191    262144  128M ef EFI (FAT-12/16/32)
# /dev/sdb2          264192 268699647 268435456  128G 83 Linux
# /dev/sdb3       268699648 436471807 167772160   80G  6 FAT16


# SSD#1 & SSD#2 identifier
# use `lsblk --nodeps --output +PtUUId` to get disks identifier (PtUUId)
input='11111111'
output='22222222'


set -o errexit
set -o nounset
set -o pipefail


# possible release of system
_finish() {
	# line feed if interrupted (Ctrl-C during blocksync-fast)
	echo -n $'\e[6n'
	read -srdR cursor
	(( ${cursor#*;} != 1 )) &&
		echo $'\n'
	echo -n $'\e[0m'
	# remount ESP#1 if necessary
	[[ -n "${_esp:-}" ]] &&
		echo ". remount ESP system partition" &&
			mount "/dev/${input}1" "${esp}"
	# wake up LUKS#1 if necessary
	[[ -n "${_luks:-}" ]] &&
		echo ". wake up LUKS system partition" &&
			fsfreeze --unfreeze "${luks}" &&
				sync --file-system "${luks}"
}
trap _finish EXIT


# SSD#1 identification
readonly input=$(
	lsblk --noheadings --nodeps --output KNAME --filter "PTUUID=='${input}'"
)
[[ -z "${input}" ]] &&
	echo "! missing system disk" >&2 &&
		exit 1
# SSD#2 identification
readonly output=$(
	lsblk --noheadings --nodeps --output KNAME --filter "PTUUID=='${output}'"
)
[[ -z "${output}" ]] &&
	echo "! missing backup system disk" >&2 &&
		exit 1


# check that SSD#2 is not mounted
[[ -n "$(
	lsblk --noheadings --output mountpoint --filter "kname=='${output}1'"
)" || -n "$(
	lsblk --noheadings --output mountpoint --filter "pkname=='${output}2'"
)" ]] &&
	echo "! backup system disk is mounted" >&2 &&
		exit 1


# checking ESP size
[[ $(
	lsblk --noheadings --nodeps --output SIZE --bytes "/dev/${input}1"
) != $(
	lsblk --noheadings --nodeps --output SIZE --bytes "/dev/${output}1"
) ]] &&
	echo "! ESP partitions differ in size" >&2 &&
		exit 1
# check LUKS size
[[ $(
	lsblk --noheadings --nodeps --output SIZE --bytes "/dev/${input}2"
) != $(
	lsblk --noheadings --nodeps --output SIZE --bytes "/dev/${output}2"
) ]] &&
	echo "! LUKS partitions differ in size" >&2 &&
		exit 1


# warning ESP#1
readonly esp=$( awk "\$1~/\/dev\/${input}1/{print \$2}" /proc/mounts )
[[ -n "${esp}" ]] &&
	echo ". ESP system partition will be inaccessible during operation"
# warning LUKS#1
readonly luks=$( lsblk --noheadings --output mountpoint --filter "pkname=='${input}2'" )
[[ -n "${luks}" ]] &&
	echo ". LUKS system partition will be inaccessible during the operation"


# synchronization validation
read -r -s -p \
$'\e[1;33m!\e[0m synchronization of \e[1m'\
"$( lsblk --noheadings --nodeps --output model "/dev/${input}" )"\
$'\e[0m to \e[1;33m'\
"$( lsblk --noheadings --nodeps --output model "/dev/${output}" )"\
$'\e[0m\n'\
"? continue (Enter) or cancel (Ctrl-C)"$'\n'


# ESP#1 unmount (FAT32 standby not supported)
# (_esp and _luks are markers used by _finish)
sync --file-system "${esp}"
sysctl --quiet vm.drop_caches=3
[[ -n "${esp}" ]] &&
	echo ". unmounting ESP system partition" &&
		umount --lazy "${esp}"
_esp=x
# LUKS1#1 standby
sync --file-system "${luks}"
sysctl --quiet vm.drop_caches=3
[[ -n "${luks}" ]] &&
	echo ". LUKS system partition standby" &&
		fsfreeze --freeze "${luks}"
_luks=x


# block-level synchronization based on blocksync-fat
# https://github.com/nethappen/blocksync-fast
# uncomment the dry variable to test the script
#dry="--dont-write"
bin="blocksync-fast"
opt=( --block-size=4M --buffer-size=64M --sync-writes --show-progress )
# block-level synchronization from ESP#1 to ESP#2
echo
"$bin" "${dry:-}" --src="/dev/${input}1" --dst="/dev/${output}1" "${opt[@]}"
# block-level synchronization from LUKS#1 to LUKS#2
# (duration of synchronization depends on size of partition,
# volume of changes introduced, speed of buses used and
# velocity of the devices used)
echo $'\e[33m'
"$bin" "${dry:-}" --src="/dev/${input}2" --dst="/dev/${output}2"  "${opt[@]}"
echo $'\e[32m'
echo ". backup system disk can be disconnected"
