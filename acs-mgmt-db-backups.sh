#!/bin/bash
## This script creates a dump of the CloudStack database and rotates
##   old dumps.
##
## Author: Melanie Desaive <m.desaive@mailbox.org>
##
## Usage: cloudstack-management-db-backup.sh [options]
##
## Options:
##   -h, --help    Display this message.
##   --testing     Does not actually dump the database, only testing with empty files.
##   --debug       Prints lots of debug information.
##
## Examples:
##
## Additional infos:
##
## TODO:
##
##  * Configure and use username and password for mysql authentication.

# source ./libmel.sh

DEBUG=false   # More output.
TESTING=false # Does not actually dump the database, only testing with empty files.

BASEDIR=/root/backups-management-db
BASENAME_DUMP_CLOUDDB="dump-clouddb"
BASENAME_DUMP_USAGEDB="dump-usagedb"

TODAYSTRING=$(date '+%Y-%m-%d')
KEEPDAYS=7
DELETEDATESTRING=$(date --date "$KEEPDAYS days ago" '+%Y-%m-%d')

dbg_echo() { 
    if $DEBUG  
    then 
        echo "$*" 
    fi 
}

logger "$0 - Sichern einer neuen Rotation der CloudStack Datenbanken cloud und cloud_usage."

dbg_echo "Deleting all dumps older or equal ${DELETEDATESTRING}"

CLOUDDB_NAME="cloud"
USAGEDB_NAME="cloud_usage"

# TODO: Not yet using username and password for authentication
# DB_USER=""
# DB_PW=""
 
usage() { 
    [ "$*" ] && echo "$0: $*" 
    sed -n '/^##/,/^$/s/^## \{0,1\}//p' "$0" 
    exit 2 
} 2>/dev/null

while [ $# -gt 0 ]; do
    case $1 in
    (-h|--help) shift; usage 2>&1;;
    (-p|--profile) set_profile "${2}"; shift 2;;
    (--testing) TESTING=true; shift 1;;
    (--no-testing) TESTING=false; shift 1;;
    (--debug) DEBUG=true; shift 1;;
    (--no-debug) DEBUG=false; shift 1;;
    (--) shift; break;;
    (-*) usage "$1: unknown option";;
    (*) break;;
    esac
done

# Create base directory if necessary.

if [[ ! -e "${BASEDIR}" ]]; then
    dbg_echo "Creating ${BASEDIR}."
    mkdir "${BASEDIR}"
elif [[ ! -d "${BASEDIR}" ]]; then
    dbg_echo "${BASEDIR} already exists but is not a directory" 1>&2
else
    dbg_echo "${BASEDIR} already exists."
fi

# Create dump

DUMP_CLOUDDB_NAME="${BASEDIR}/${BASENAME_DUMP_CLOUDDB}-${TODAYSTRING}.sql"
DUMP_USAGEDB_NAME="${BASEDIR}/${BASENAME_DUMP_USAGEDB}-${TODAYSTRING}.sql"

if [ -f "${DUMP_CLOUDDB_NAME}" ] || [ -f "${DUMP_USAGEDB_NAME}" ]
then
    echo "Aborting backup due to conflicting dump file names."
    logger "$0 - Dump abgebrochen - es liegen schon Dateien mit entsprechendem Namen vor."
    exit 1
fi

dbg_echo "Dumping to:"
dbg_echo "  ${DUMP_CLOUDDB_NAME}"
dbg_echo "  ${DUMP_USAGEDB_NAME}"

if $TESTING
then
    dbg_echo "Testmode: Only creating empty files."
    touch "${DUMP_CLOUDDB_NAME}"
    touch "${DUMP_USAGEDB_NAME}"
else
    dbg_echo "Creating CloudDB dump."
    mysqldump --events --triggers --add-drop-table ${CLOUDDB_NAME} > "${DUMP_CLOUDDB_NAME}" || { echo 'Dump failed.' ; logger "$0 - Dump von cloud fehlgeschlagen."; exit 1; }
    dbg_echo "Creating UsageDB dump."
    mysqldump --events --triggers --add-drop-table ${USAGEDB_NAME} > "${DUMP_USAGEDB_NAME}" || { echo 'Dump failed.' ; logger "$0 - Dump von cloud_usage fehlgelschlagen."; exit 1; }
fi

# Delete old dumps

dbg_echo "All cloud DB dumps:"
for file in $(find ${BASEDIR} -name "${BASENAME_DUMP_CLOUDDB}-*" | sort)
do
    timestamp=$(echo "$file" | sed -r -n  's/.*([0-9]{4}-[0-9]{2}-[0-9]{2}).*$/\1/p')
    if [ ! "$timestamp" \> "$DELETEDATESTRING" ]
    then
        dbg_echo Deleting "$timestamp"
        rm "${BASEDIR}/${BASENAME_DUMP_CLOUDDB}-${timestamp}.sql"
    else
        dbg_echo Keeping "$timestamp"
    fi
done

echo
dbg_echo "All usage DB dumps:"
for file in $(find ${BASEDIR} -name "${BASENAME_DUMP_USAGEDB}-*" | sort)
do
    timestamp=$(echo "$file" | sed -r -n  's/.*([0-9]{4}-[0-9]{2}-[0-9]{2}).*$/\1/p')
    if [ ! "$timestamp" \> "$DELETEDATESTRING" ]
    then
        dbg_echo Deleting "$timestamp"
        rm "${BASEDIR}/${BASENAME_DUMP_USAGEDB}-${timestamp}.sql"
    else
        dbg_echo Keeping "$timestamp"
    fi
done

logger "$0 - Cloud und cloud_usage Datenbank erfolgreich gesichert."
