#!/bin/bash
#
#	 ########################################################################
#	#                                                                        #
#	#	P4 TRIVIAL BACKUP SCRIPT					 #
#	#																		 #
#	#	this script generates a full(!) backup on each run               #
#	#	(c) 2011 by Dennis Rochel, jakez@imount.de			 #
#	#                                                                        #
#	 ########################################################################
#
# creates backups of essential files
#
#	1.: Mount Backup-Disk
#	2.: Backup SVN-Repositories
#	3.: Backup Gallery3
#	4.: unmount Backup-Disk


#CONFIGURATION

#guess what
ADMIN_EMAIL=jakez@imount.de

#the disk-dev where the backup will be saved (mount/unmount on each run)
BACKUP_VOLUME=/dev/disk1s2

#the path to the mounted backup device
BACKUP_PATH=/Volumes/Backup/p4Backup/

#the path for the backup logfile
LOGFILE_PATH="/var/log/backup.log"

#the svn repositories which should be backed up!
SVN_REPOSITORIES="Sonntagseifen iGallery iBahn iFreetz coolibriApp xtraApp"

#how many full backups should be stored on the backup drive
TOTAL_BACKUP_NUM=4
#-



LOG_COUNTER=0
HAS_ERROR=0
CURRENT_BACKUP_DIR=$(date +"%Y-%m-%d")


	# DESCRIPTION
	# simple log function - used to add an additional timestamp
	#
	# PARAMETER
	# 1 : CSTRING to log into the logfile
	# 2 : INT (0|1) - if set to 1, the log function will send an E-Mail to the administrator
	log() {
		NOW=$(date +"%m-%d-%Y %H:%M:%S")

		if [ $LOG_COUNTER == 0 ]
		then
			echo $NOW ' : ' '------------------ START PROCESSING ------------------------' >> $LOGFILE_PATH 
		fi
		
		if (( $2 == 1 ))
		then
			echo $1 | mail -s "P4 Backup Error" $ADMIN_EMAIL 
		fi
		
		#write the logfile
		echo $NOW ' : ' $1 >> $LOGFILE_PATH
		
		#also print the log information out to shell
		echo 'LOG: '$1
		
		LOG_COUNTER=$((LOG_COUNTER+1))
	}

#mount backup disk
/usr/sbin/diskutil mount $BACKUP_VOLUME


#check if the mount was successfull
if /sbin/mount | grep "${BACKUP_VOLUME}" > /dev/null
then

	cd ${BACKUP_PATH};
	
	#get the name of the last dir created inside the backup folder.
	#the "grep -" pipe-part excludes the logfile.log file inside this
	#directory (because it countains no "-")
	LAST_BACKUP_DIR=$( ls -1 -tr . | grep - | tail -1)
	
	#get the backup-size of the last backup run	
	LAST_BACKUP_SIZE=$(du -ks $LAST_BACKUP_DIR | awk '{print $1}')
		
		
	if [ $LAST_BACKUP_DIR == $CURRENT_BACKUP_DIR ]
	then
		log 'LAST_BACKUP_DIR and CURRENT_BACKUP_DIR are the same :-/. Name of the directories: '$CURRENT_BACKUP_DIR 1
		HAS_ERROR=1
		exit
	fi
	
		
	mkdir $CURRENT_BACKUP_DIR
	#TODO: check if directory already exists
	
	log 'backup gallery3 files' 0
	tar cf $CURRENT_BACKUP_DIR/gallery3.tar /Applications/MAMP/htdocs/gallery3/
	
	log 'backup gallery3 database' 0
	/Applications/MAMP/Library/bin/mysqldump --opt -u root gallery3 > $CURRENT_BACKUP_DIR/gallery3.sql
	
	
	for repo in `echo $SVN_REPOSITORIES`
	do
		log 'backup repository '$repo 0
		svnadmin dump /Users/svn/svnroot/$repo > $CURRENT_BACKUP_DIR/repository_$repo.dump
	done
	
	
	# check if the file size is identically (with a defined limit of tolerance) 
	# with the backup created the run before -> otherwise inform me
	
	#get the backup-size of the CURRENT backup run	
	CURRENT_BACKUP_SIZE=$(du -ks $CURRENT_BACKUP_DIR | awk '{print $1}')
		
	if (("$CURRENT_BACKUP_SIZE" < "$LAST_BACKUP_SIZE"))
	then
		log 'the current backup is smaller than the backup before - please check backup file manually. CURRENT_BACKUP_SIZE: '$CURRENT_BACKUP_SIZE'kb - LAST_BACKUP_SIZE: '$LAST_BACKUP_SIZE'kb' 1
		HAS_ERROR=1
	fi
	
	
	if (( $HAS_ERROR==0 ))
	then
		#now the oldest backup directory will be removed, if the backup-num is reached.
		#thus first of all the count of all backups will be calculated
		
		# use find command to get all subdirs name in DIRS variable
		DIRS=$(find . -type d)
 		BACKUP_COUNT=0
 		
		# loop thought each dir to get the number of files in each of subdir
		for CURRENT_DIR in $DIRS
		do
			if [ \! $CURRENT_DIR == '.' ]
			then
				BACKUP_COUNT=`expr $BACKUP_COUNT + 1`
			fi
		done
		
		log 'the current BACKUP_COUNT is:'$BACKUP_COUNT 0

		if (("$BACKUP_COUNT" > "$TOTAL_BACKUP_NUM"))
		then
			#get the oldest directory in the backup dir
			DELETE_THIS_BACKUP=$(ls -1t|tail -1)

			#delete the oldest backup
			rm -fr $DELETE_THIS_BACKUP
			
			log 'Deleting the following backup: '$DELETE_THIS_BACKUP 0
		fi
	fi
	
	#unmount the backup-disk
	/usr/sbin/diskutil unmount $BACKUP_VOLUME
	
	#check if the unmount was successfully
	if mount | grep "${BACKUP_VOLUME}" > /dev/null
	then
		log "Unmount of the Backup-Dir failed." 1
	fi

else
	log 'Mounting the backup drive generates an error' 1
fi
