#!/usr/bin/bash

# ce script permet la synchronisation au niveau bloc du disque système
# (SSD#1 0x11111111) vers le disque système de secours (SSD#2 0x222222).
#
# les deux premières partitions (ESP/LUKS) doivent avoir la même taille.
#
# Disque /dev/sda : 465,76 GiB, 500107862016 octets, 976773168 secteurs
# Modèle de disque : Portable SSD T5 
# Unités : secteur de 1 × 512 = 512 octets
# Taille de secteur (logique / physique) : 512 octets / 512 octets
# taille d'E/S (minimale / optimale) : 512 octets / 33553920 octets
# Type d'étiquette de disque : dos
# Identifiant de disque : 0x11111111
# Périphérique Amorçage     Début       Fin  Secteurs Taille Id Type
# /dev/sda1    *             2048    264191    262144   128M ef EFI (FAT-12/16/32)
# /dev/sda2                264192 268699647 268435456   128G 83 Linux
# /dev/sda3             268699648 369362943 100663296    48G  7 HPFS/NTFS/exFAT
# /dev/sda4             369362944 906217979 536855036   256G 83 Linux
#
# Disque /dev/sdb : 223,57 GiB, 240057409536 octets, 468862128 secteurs
# Modèle de disque : SABRENT         
# Unités : secteur de 1 × 512 = 512 octets
# Taille de secteur (logique / physique) : 512 octets / 512 octets
# taille d'E/S (minimale / optimale) : 4096 octets / 4096 octets
# Type d'étiquette de disque : dos
# Identifiant de disque : 0x22222222
# Périphérique Amorçage     Début       Fin  Secteurs Taille Id Type
# /dev/sdb1    *             2048    264191    262144   128M ef EFI (FAT-12/16/32)
# /dev/sdb2                264192 268699647 268435456   128G 83 Linux
# /dev/sdb3             268699648 436471807 167772160    80G  6 FAT16


set -o errexit
set -o nounset
set -o pipefail


# libération éventuelle du système
_finish() {
	# saut de ligne si interruption (Ctrl-C durant blocksync-fast)
	echo -n $'\e[6n'
	read -srdR cursor
	(( ${cursor#*;} != 1 )) &&
		echo $'\n'
	echo -n $'\e[0m'
	# remontage éventuel de ESP#1
	[[ -n "${_esp:-}" ]] &&
		echo ". remontage de la partition système ESP" &&
			mount "/dev/${input}1" "${esp}"
	# réactivation éventuelle de LUKS#1
	[[ -n "${_luks:-}" ]] &&
		echo ". réactivation de la partition système LUKS" &&
			fsfreeze --unfreeze "${luks}" &&
				sync --file-system "${luks}"
}
trap _finish EXIT


# identification de SSD#1
input='11111111'
readonly input=$(
	lsblk --noheadings --nodeps --output KNAME --filter "PTUUID=='${input}'"
)
[[ -z "${input}" ]] &&
	echo "! disque système manquant" >&2 &&
		exit 1
# identification de SSD#2
output='22222222'
readonly output=$(
	lsblk --noheadings --nodeps --output KNAME --filter "PTUUID=='${output}'"
)
[[ -z "${output}" ]] &&
	echo "! disque système de secours manquant" >&2 &&
		exit 1


# vérification du non montage de SSD#2
[[ -n "$(
	lsblk --noheadings --output mountpoint --filter "kname=='${output}1'"
)" || -n "$(
	lsblk --noheadings --output mountpoint --filter "pkname=='${output}2'"
)" ]] &&
	echo "! le disque système de secours est monté" >&2 &&
		exit 1


# vérification de la taille des ESP
[[ $(
	lsblk --noheadings --nodeps --output SIZE --bytes "/dev/${input}1"
) != $(
	lsblk --noheadings --nodeps --output SIZE --bytes "/dev/${output}1"
) ]] &&
	echo "! la taille des partitions ESP diffère" >&2 &&
		exit 1
# vérification de la taille des LUKS
[[ $(
	lsblk --noheadings --nodeps --output SIZE --bytes "/dev/${input}2"
) != $(
	lsblk --noheadings --nodeps --output SIZE --bytes "/dev/${output}2"
) ]] &&
	echo "! la taille des partitions LUKS diffère" >&2 &&
		exit 1


# avertissement montage ESP#1
readonly esp=$( awk "\$1~/\/dev\/${input}1/{print \$2}" /proc/mounts )
[[ -n "${esp}" ]] &&
	echo ". la partition système ESP sera inaccessible durant l'opération"
# avertissement montage LUKS#1
readonly luks=$( lsblk --noheadings --output mountpoint --filter "pkname=='${input}2'" )
[[ -n "${luks}" ]] &&
	echo ". la partition système LUKS sera inaccessible durant l'opération"


# validation de la synchronisation
read -r -s -p \
$'\e[1;33m!\e[0m synchronisation de \e[1m'\
"$( lsblk --noheadings --nodeps --output model "/dev/${input}" )"\
$'\e[0m vers \e[1;33m'\
"$( lsblk --noheadings --nodeps --output model "/dev/${output}" )"\
$'\e[0m\n'\
"? continuer (Entrer) ou annuler (Ctrl-C)"$'\n'


# démontage ESP#1 (mise en veille FAT32 non supportée)
# (_esp et _luks sont des marqueurs utilisés par _finish)
sync --file-system "${esp}"
sysctl --quiet vm.drop_caches=3
[[ -n "${esp}" ]] &&
	echo ". démontage de la partition système ESP" &&
		umount --lazy "${esp}"
_esp=x
# mise en veille de LUKS1#1
sync --file-system "${luks}"
sysctl --quiet vm.drop_caches=3
[[ -n "${luks}" ]] &&
	echo ". mise en veille de la partition système LUKS" &&
		fsfreeze --freeze "${luks}"
_luks=x


# la synchronisation niveau bloc repose sur blocksync-fat
# https://github.com/nethappen/blocksync-fast
# décommenter la variable dry pour tester le script
#dry="--dont-write"
bin="blocksync-fast"
opt=( --block-size=4M --buffer-size=64M --sync-writes --show-progress )
# synchronisation niveau bloc de ESP#1 vers ESP#2
echo
"$bin" "${dry:-}" --src="/dev/${input}1" --dst="/dev/${output}1" "${opt[@]}"
# synchronisation niveau bloc de LUKS#1 vers LUKS#2
# (la durée de cette synchronisation dépend de la taille de la partition,
# du volume des changements introduits, de la vitesse des bus empruntés et
# de la velocité des périphériques utilisés)
echo $'\e[33m'
"$bin" "${dry:-}" --src="/dev/${input}2" --dst="/dev/${output}2"  "${opt[@]}"
echo $'\e[32m'
echo ". le disque système de secours peut être débranché"


# ~15 minutes pour synchroniser 128Go
#
# # time ./blksync 
# . la partition système ESP sera inaccessible durant l'opération
# . la partition système LUKS sera inaccessible durant l'opération
# ! synchronisation de Samsung Portable SSD T5 vers SABRENT
# ? continuer (Entrer) ou annuler (Ctrl-C)
# . démontage de la partition système ESP
# . mise en veille de la partition système LUKS
# 
# Syncs and flushes data to a disk device defined by the buffer size in bytes
# Operation mode: block-sync
# Source device: '/dev/sda1' has size of 128.00 MiB, 134217728 bytes
# Target device: '/dev/sdb1' has size of 128.00 MiB, 134217728 bytes
# Warning: works without digest file.
# Works without reads from digest file, data to compare will be read from the destination device
# Buffer size: 64.00 MiB, 67108864 bytes per device
# Block size: 4.00 MiB, 4194304 bytes per block out of 32 blocks
# Progress: 100%
# Updated: 0/32 blocks, 0/134217728 bytes.
# 
# Syncs and flushes data to a disk device defined by the buffer size in bytes
# Operation mode: block-sync
# Source device: '/dev/sda2' has size of 128.00 GiB, 137438953472 bytes
# Target device: '/dev/sdb2' has size of 128.00 GiB, 137438953472 bytes
# Warning: works without digest file.
# Works without reads from digest file, data to compare will be read from the destination device
# Buffer size: 64.00 MiB, 67108864 bytes per device
# Block size: 4.00 MiB, 4194304 bytes per block out of 32768 blocks
# Progress: 100.0%
# Updated: 1620/32768 blocks, 6794772480/137438953472 bytes.
# 
# . le disque système de secours peut être débranché
# . remontage de la partition système ESP
# . réactivation de la partition système LUKS
# 
# real	14m16,972s
# user	0m30,646s
# sys	4m2,079s
