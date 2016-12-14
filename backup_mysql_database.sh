#!/bin/bash
# script to backup a single mysql database
# # GNewton 2013.10.31
# # Iyad Kandalaft 2016.12.12
#
# Assumes in directory of (this) script
# Stop if any error occurs
set -e
LOG=true
usage(){
    echo "Usage: $0 host userid password dbName backupDirectory backupFileName errorLogFilename"
}

readonly DEPENDENCIES=(nice cat mysqldump gzip sha1sum date)

#Error Codes
readonly ERROR_USAGE_1=1
readonly ERROR_MYSQLDUMP_FAIL_2=2
readonly ERROR_GZIP_TEST_FAIL_3=3
readonly ERROR_SHA_CREATE_FAIL_4=4

readonly MYSQL_DUMP="mysqldump"

function init {
    log "check dependencies"
    check_dependencies ${DEPENDENCIES[@]}
    if [ ! $? ]; then
	usage
    fi
    log "check dependencies done"
}


function main {

    . ./util.sh

    log "Running backup_single_database.sh $@" 
    echo "foo"
    if [ $# -ne 7 ]; then
	echo "Invalid number of arguement" >&2
	usage
	exit $ERROR_USAGE_1
    fi

    init
 
    readonly DB_HOST="$1"
    readonly DB_PORT="$2"
    readonly DB_USER="$3"
    readonly DB_PASSWORD="$4"

    readonly DATABASE_NAME="$5"

    readonly BACKUP_FILE_NAME="$6"
    readonly ERROR_LOG_FILE_NAME="$7"

    readonly DEFAULT_CHARACTER_SET='utf8'

    TIME_STAMP=$(date "+%F %H:%M:%S%t%s")


    readonly COMPRESSED_BACKUP_FILENAME=${BACKUP_FILE_NAME}.gz

    echo "START: $TIME_STAMP" > ${BACKUP_FILE_NAME}.meta
    echo "BACKUP_FILE:  $COMPRESSED_BACKUP_FILENAME" >> ${BACKUP_FILE_NAME}.meta

    deleteIfExists ${BACKUP_FILE_NAME}
    deleteIfExists ${COMPRESSED_BACKUP_FILENAME}

    readonly START_NO_KEYS="SET FOREIGN_KEY_CHECKS=0;"
    readonly END_NO_KEYS="SET FOREIGN_KEY_CHECKS=0;"

    QQ="$(echo $START_NO_KEYS $END_NO_KEYS| wc -c)"

    
    log "Starting backup of database: $DATABASE_NAME data to compressed file: $COMPRESSED_BACKUP_FILENAME"
    { nice -19 cat <(echo "$START_NO_KEYS") <($MYSQL_DUMP \
	--opt \
	--comments=0 \
	--compress \
	--default-character-set=${DEFAULT_CHARACTER_SET} \
	--hex-blob \
	--host=${DB_HOST}\
    	--max-allowed-packet=1G \
	--no-autocommit \
	--password=${DB_PASSWORD} \
	--port=${DB_PORT} \
	--single-transaction \
	--skip-dump-date \
	--routines \
	--triggers \
	--events \
	--user=${DB_USER} \
	$DATABASE_NAME) <(echo "$END_NO_KEYS") | nice gzip -c > $COMPRESSED_BACKUP_FILENAME; } 2>> ${ERROR_LOG_FILE_NAME}|| { echo "mysqldump command failed: exit code $?"; exit 1; }


    lenOut="$(gunzip -c $COMPRESSED_BACKUP_FILENAME| wc -c)"
    echo $lenOut


    if [ "$lenOut" -le "$QQ" ]; then
	#backup file only contains the KEYS text thus some failure
        exit 2
    fi
    
    log "Verifying GZip of $COMPRESSED_BACKUP_FILENAME"
    # Verify gzip OK
    gzip --test $COMPRESSED_BACKUP_FILENAME

    log "Creating sha256sum of $COMPRESSED_BACKUP_FILENAME"
    # Make sha256 of file
    sha1sum $COMPRESSED_BACKUP_FILENAME | sed 's, .*/, ,' > ${COMPRESSED_BACKUP_FILENAME}.sha1

    TIME_STAMP=$(date +%F%t%H:%M:%S%t%s)
    echo "END: $TIME_STAMP" >> ${BACKUP_FILE_NAME}.meta
}


################
main $@
################

