#!/bin/sh

FS_TEST_RO="iso9660 jffs2"
FS_TEST_RW="vfat ext2 ext3 ext4"
FS_TEST_NETWORK="nfs"

FS_TEST_NFS_ROOT="/var/nfs_test"
FS_TEST_NFS_PREPARE="sudo systemctl restart "{rpcbind,rpc-mountd,rpc-idmapd}\;

ROOT_DIR=.
BASE_DIR=$(dirname $0)

START_SCRIPT=$ROOT_DIR/conf/start_script.inc
CONT_BASE=$ROOT_DIR/scripts/continuous
CONT_FS_MANAGE=$CONT_BASE/fs/img-manage.sh
CONT_RUN=$CONT_BASE/run.sh

IMG_RO_CONTENT=$BASE_DIR/img-ro
IMG_RW_CONTENT=$BASE_DIR/img-rw
IMG_RW_GOLD=$BASE_DIR/img-rw-gold

posted_ret=0
check_post_exit() {
	ret=$?
	if [ 0 -ne $ret ]; then
		echo - - - - - - - - - - - - - - -
		echo ERROR: $1
		echo - - - - - - - - - - - - - - -

		posted_ret=$ret
	fi
}

qemu_changed_startscript=
run_qemu_fs() {
	FS=$1
	IMG=$2

	cp $START_SCRIPT $START_SCRIPT.old
	qemu_changed_startscript=1

	img_mount=
	QEMU_MOUNT_HD="\"mount -t $FS /dev/hda /mnt/fs_test\","
	case $FS in
		vfat | ext2 | ext3 | ext4 | qnx6)
			img_mount="$QEMU_MOUNT_HD"
			;;
		jffs2)
			img_mount="\"mkfs -t $FS /dev/hda\",$QEMU_MOUNT_HD"
			;;
		iso9660)
			img_mount="\"mount -t $FS /dev/cd0 /mnt/fs_test\","
			;;
		cifs | nfs)
			img_mount="\"mount -t $FS 10.0.2.10:$IMG /mnt/fs_test\","
			;;
	esac

	echo $img_mount >> $START_SCRIPT
	echo \"test -t fs_test\", >> $START_SCRIPT
	echo \"umount /mnt/fs_test\", >> $START_SCRIPT

	make &> /dev/null

	img_run=
	case $FS in
		vfat | ext2 | ext3 | ext4 | qnx6 | jffs2)
			img_run="-hda $IMG"
			;;
		iso9660)
			img_run="-cdrom $IMG"
			;;
		cifs | nfs)
			;;
	esac

	$CONT_RUN generic/qemu "$img_run"
	#./scripts/qemu/auto_qemu $img_run
	check_post_exit "qemu run failed"

	mv -f $START_SCRIPT.old $START_SCRIPT
}

run_qemu_cleanup() {
	if [ ! -z $qemu_changed_startscript ]; then
		make &> /dev/null
	fi
}

banner() {
	fs="$1"

	echo  ================================
	echo Starting test "$fs" filesystem
	echo  ================================
}

for f in $FS_TEST_RO; do
	img=$BASE_DIR/$f.img

	banner "$f (ro)"
	$CONT_FS_MANAGE $f $img build $IMG_RO_CONTENT

	run_qemu_fs $f $img
done

for f in $FS_TEST_RW; do
	img=$BASE_DIR/$f.img
	img_work=$img.work

	banner "$f (rw)"

	$CONT_FS_MANAGE $f $img build $IMG_RW_CONTENT

	cp $img $img_work

	run_qemu_fs $f $img_work

	$CONT_FS_MANAGE $f $img_work check $IMG_RW_GOLD
	check_post_exit "fs content differ from expected"

	rm $img_work
done

for f in $FS_TEST_NETWORK; do
	banner "$f (net)"

	case $f in
		nfs)
			$CONT_FS_MANAGE $f $FS_TEST_NFS_ROOT build_dir $IMG_RW_CONTENT

			eval $FS_TEST_NFS_PREPARE

			run_qemu_fs $f $FS_TEST_NFS_ROOT

			$CONT_FS_MANAGE $f $FS_TEST_NFS_ROOT check_dir $IMG_RW_GOLD
			check_post_exit "fs content differ from expected"
			;;
	esac
done

run_qemu_cleanup

exit $posted_ret
