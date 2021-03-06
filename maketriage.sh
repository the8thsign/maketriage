#! /bin/sh

# TRIAGE DRIVE DUPLICATION SCRIPT

# This script should be run from the same directory as the IMAGES and ASD folder, which contains all the .dmg files for restoring triage and ASD partitions.


# root folder
# |   |-- IMAGES 
# |   +-- ASD
# +-- triage.sh


###############################################################################


# Check to see user has root permissions. ASR needs root to run and instead of asking each time, we prompt only once.
ROOT_UID="0"

# Check if run as root
if [ "$UID" -ne "$ROOT_UID" ] ; then
	echo "You must be root to do that!"
	exit 1
fi

clear
# Get current location of the script. This lets us run the script from anywhere with the images being relative.
dir="$( cd "$( dirname "$0" )" && pwd )"

clear
# Step two pulls the disk identifier from the drive you want to image (e.g. for /dev/disk0s4, the disk identifier is "0").  We're doing it this way because if you try to run the ASR restores using volume names (e.g. /Volumes/Snow\ Triage), the restore will fail if for some reason the volume you're trying to restore isn't mounted.  Sometimes unmounting a volume causes other volumes on the same drive to unmount as well, and if they don't remount fast enough you have problems.  Connected drives are always available through /dev however, so this is a more reliable way to restore.  This step also ensures that you will erase the correct drive if you have multiple drives attached to the computer, since the device tree numbers drives in the order they are connected to the computer.
echo "Drag a mounted partition from the drive you"
echo "want to re-image to the Terminal window and"
echo "hit the Enter key."
read drive
diskid=( `diskutil info -plist "$drive" | grep -C 1 "ParentWholeDisk" | grep -v "Volumes" | sed 's [^0-9]  g' | grep -v '^$'` )

clear
# Choose the type of drive to create.  Genius Bar drives have triage, install, and ToolBox. ASD includes both OS and EFI and Blank Board Serializer.
echo "To create a ASD Drive, press a"
echo "To create a Genius Bar Drive, press b"
read -n 1 answer
	case "$answer" in

# This next section is for the ASD drive:
a|A)
	clear
	echo "Creating APM Partitioning for"
	echo "ASD Drive"

# This step reformats the drive with Apple Partition Map and creates a single partition called NEW.  This step is necessary because if you have diskutil partition a blank disk with all of the partitions, it will number all of the devices with odd numbers only (i.e. disk2s3, disk2s5, etc.).  We want the partitions to number sequentially, so we have to create a single partition first, then use the splitPartition command to split it.  This numbers all of the new partitions in order, starting with 3.  Partitions 1 and 2 contain formatting information in APM.
	diskutil partitionDisk /dev/disk"$diskid" APMFormat JHFS+ NEW 0b

# This step splits the NEW partition into multiple partitions so we can restore our disk images to them.  The formatting for this command is "volumeformat volumename volumesize."  All partitions are formatted JHFS+ (Journaled HFS+).  The names and numbers are there just for the sake of keeping the partitions straight in case you want to add some new ones or change the sizes, and the sizes are self-explanatory.  The Free is set to 0b because if the last partition in the scheme is set to 0 it will automatically utilize all of the remaining free space on the drive.
	diskutil splitPartition /Volumes/NEW JHFS+ 3-152-OS 10g JHFS+ 4-150-OS 10g JHFS+ 5-149-OS 10g JHFS+ 6-148-OS 10g JHFS+ 7-147-OS 10g JHFS+ 8-146-OS 10g JHFS+ 9-145-OS 10g JHFS+ 10-144-OS 10g JHFS+ 11-142-OS 10g JHFS+ 12-140-OS 10g JHFS+ 13-139-OS 10g JHFS+ 14-138-OS 10g JHFS+ 15-132-OS 10g JHFS+ 16-123-OS 10g JHFS+ 17-116-OS 10g JHFS+ 18-108-OS 10g JHFS+ 19-151-EFI .5g JHFS+ 20-150-EFI .5g JHFS+ 21-149-EFI .5g JHFS+ 22-148-EFI .5g JHFS+ 23-147-EFI .5g JHFS+ 24-146-EFI .5g JHFS+ 25-145-EFI .5g JHFS+ 26-144-EFI .5g JHFS+ 27-142-EFI .5g JHFS+ 28-140-EFI .5g JHFS+ 29-139-EFI .5g JHFS+ 30-138-EFI .5g JHFS+ 31-132-EFI .5g JHFS+ 32-123-EFI .5g JHFS+ 33-116-EFI .5g JHFS+ 34-108-EFI .5g JHFS+ 35-Serializer .5g JHFS+ FREE 0b


# We're setting our count to 2 because we want to ignore diskXs1 and diskXs2, since they hold APM formatting info and we're not restoring anything to them
	count=2

# This starts a count that will stop when we reach 33, which is the partition number of the ToolBox.
# If you were to change the number of partitions on the drive, you'd need to change this number.
	while [ $count -lt 35 ]

# This part is the actual restore command using ASR.  First we add 1 to the count (so the first partition it restores will be 3) then we tell it to restore using a disk image whose name starts with the count number and is followed by a dash and then the wildcard (so the actual remainder of the filename is irrelevant), and that it should pull that disk image from the IMAGES directory which is located in the same directory as this script (the "dir" variable, which we got in the first step of the script).  The destination of the restore is on whatever disk we told it to erase in step 2, and its partition number is the same as the count.  The --erase tag initiates a block-level copy, --noprompt restores without requiring a confirmation, and --noverify restores the partition without going over it a second time to verify the restore (cuts restore time in half).
	do
		count=`expr $count + 1`
		asr restore --source "$dir"/ASD/$count-* --target /dev/disk"$diskid"s$count --erase --noprompt --noverify
		echo "Partition $count completed"
	done
	echo

# This could be a lie, since ASR isn't verifying so there's no way to know if everything restored correctly.  But it's been true every time I've run it.  You'll be able to tell if you open Disk Utility and all of the icons show up correctly under the device.  If anything still has its generic firewire icon, it needs to be re-restored.
	echo "ASD Drive created successfully"
;;

# This next section is for the Genius Bar drive:
b|B)
	clear
	echo "Creating APM Partitioning for"
	echo "Genius Bar Triage Drive"

# Same as above.
	diskutil partitionDisk /dev/disk"$diskid" APMFormat JHFS+ NEW 0b

# Same as above, except no ASD partitions.
	diskutil splitPartition /Volumes/NEW JHFS+ 3-MountainLionTriage 30g JHFS+ 4-LionTriage 30g JHFS+ 5-SnowTriage 20g JHFS+ 6-LeopardTriage 20g JHFS+ 7-MountainLionInstall 8g JHFS+ 8-LionInstall 8g JHFS+ 9-SnowInstall 8g JHFS+ 10-LeopardInstall 8g JHFS+ ToolBox 0b

# Same as above.
	count=2

# This part is different.  Because the ToolBox's disk image is numbered 28, we can't let the script just run through the numbers because the Bar drive only has 11 partitions on it.  So we have it stop at 10 and then put in the last ASR command manually.
# If you were to change the number of partitions on the drive, you'd need to change this number.
	while [ $count -lt 10 ]

# Same as above.
	do
		count=`expr $count + 1`
		asr restore --source "$dir"/IMAGES/$count-* --target /dev/disk"$diskid"s$count --erase --noprompt --noverify
		echo "Partition $count completed"
	done

# This is the step that manually restores the ToolBox.
# If you were to change the number of partitions on the drive, you'd need to change the numbers in here.
	asr restore --source "$dir"/IMAGES/ToolBox.dmg --target /dev/disk"$diskid"s11 --erase --noprompt --noverify
	echo "Partition ToolBox completed"
	echo

# Again, as above, this could be a total lie.
	echo "Genius Bar Drive created successfully"
;;

# This step quits the script if you type something other than a or b when it prompts you for Triage drive or ASD drive.
*)
	clear
	echo "You did not follow directions."
	echo "I am quitting now."
	exit 0
;;
esac