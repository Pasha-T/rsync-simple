#!/bin/bash

# Function to print usage
usage() {
    echo "Usage: $0 <source> <destination> <prefix> [<max_backups>]"
    echo "       source      - The directory to back up"
    echo "       destination - The backup destination directory"
    echo "       prefix      - Prefix for backup folder names"
    echo "       max_backups - Optional, maximum number of backups to keep (default is 7)"
    echo "       "
    echo "       to choose days of week for making full backup change case values at set_mode() function"
    echo "       \$FULL_BACKUPS_RETENTION set max amount of stored full backups "
    exit 1
}

# Check if correct number of arguments is provided
if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    usage
fi

# Assign arguments to variables
SOURCE=$1
DESTINATION=${2%/}  # Remove trailing slash if exists
PREFIX=$3
POSTFIX_FULL="-full"
POSTFIX_INC="-inc"
MAX_BACKUPS=${4:-7}
MIN_BACKUPS=2
FULL_BACKUPS_RETENTION=2
BASE_RSYNC_PARAMETERS="-aAXhvP --delete"                                                               # example "-aAXhvP --delete"
EXCLUDES=( "/dev/*" "/proc/*" "/sys/*" "/tmp/*" "/run/*" "/mnt/*" "/media/*" "/home/*" "/lost+found" ) # example ( "/dev/*" "/proc/*" "/sys/*" "/tmp/*" "/run/*" "/mnt/*" "/media/*" "/home/*" "/lost+found" )
CHAT_ID=6655308898
BOT_TOKEN="7266819556:AAEOi7Hw99ozCWmwi4bS_0j2v3nKAnBQ5ac"
TELEGRAM_API_URL="https://api.telegram.org/bot$BOT_TOKEN"
MODE=0
DAY_OF_WEEK=$(date +%u)                           
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
TEMP_OUTPUT="backup-v6.2.log"           #temp file to hold console output
LOG_FILE_NAME=""             # changes automatically

set_success_value_good(){
    SUCCESS=1
    STATUS="success"
}

set_success_value_fail(){
    SUCCESS=0
    STATUS="failed"
}


set_mode() {
    # Set backup mode based on the day of the week
    case $DAY_OF_WEEK in
        1 | 2 | 3 | 4 | 5 | 7)               # example "1 | 2 | 3 | 4 | 5 | 6 | 7"
            MODE=1  # Incremental Backup
            ;;
        6)                                   # example "6" 
            MODE=2  # Full Backup
            ;;
        *)
            MODE=3  # Default to Full Backup
            ;;
    esac
}

# Ensure MAX_BACKUPS is not less than MIN_BACKUPS
if [ "$MAX_BACKUPS" -lt "$MIN_BACKUPS" ]; then
    MAX_BACKUPS=$MIN_BACKUPS
fi

set_backup_dir() {
    BACKUP_DIR="${DESTINATION}/${PREFIX}${TIMESTAMP}"
}

final_print() {
    echo "success: $SUCCESS"
    echo "copy log: $COPY_LOG"
    echo "backup mode: $MODE"
    echo "status: $STATUS"
    echo "Backup started at:    $BACKUP_STARTED"
    echo "Backup finished at: $BACKUP_FINISHED"
    echo "Source:           $SOURCE"
    echo "Incremental base: $LATEST_BACKUP"
    echo "Destination:      $BACKUP_DIR"
    echo "Currently stored backups:"
    ls -dt ${DESTINATION}/*
}

find_latest_backup() {
    # Determine the latest backup to use as a base for incremental backup
    LATEST_BACKUP=$(ls -1dt ${DESTINATION}/${PREFIX}* | head -n 1)
    echo "LATEST_BACKUP: $LATEST_BACKUP"
}

perform_backup() {
    set_backup_dir

    # Build the rsync command with excludes
    RSYNC_COMMAND="rsync $BASE_RSYNC_PARAMETERS"
    for EXCLUDE in "${EXCLUDES[@]}"; do
        RSYNC_COMMAND+=" --exclude=$EXCLUDE"
    done

    case $MODE in
        2)  # Full backup
            BACKUP_DIR+="$POSTFIX_FULL"
            $RSYNC_COMMAND "$SOURCE" "$BACKUP_DIR" | tee -a "$TEMP_OUTPUT"
            ;;
        1)  # Incremental backup
            BACKUP_DIR+="$POSTFIX_INC"
            $RSYNC_COMMAND --link-dest="$LATEST_BACKUP" "$SOURCE" "$BACKUP_DIR" | tee -a "$TEMP_OUTPUT"
            ;;
        *)
            $RSYNC_COMMAND "$SOURCE" "$BACKUP_DIR" | tee -a "$TEMP_OUTPUT"
            ;;
    esac
    check_if_rsync_was_unsuccessful
}

# Check if rsync was unsuccessful
check_if_rsync_was_unsuccessful() {  
    echo -e "\n\n\n\n" | tee -a "$TEMP_OUTPUT"    
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo "Backup failed. Deleting failed backup directory $BACKUP_DIR" | tee -a "$TEMP_OUTPUT"
        rm -r "$BACKUP_DIR"
        find "$DESTINATION" -maxdepth 1 -type f -delete # Deletes all files in directory for backups
        BACKUP_FINISHED=$(date +"%Y-%m-%d_%H-%M-%S")
        set_success_value_fail        
    else
        set_success_value_good
    fi
}

# Function to delete old backups if necessary
manage_backups() {
    remove_old_full_backups(){
        # List all backup directories, sorted by name (natural sort)
        local BACKUPS_FULL=($(ls -d ${DESTINATION}/${PREFIX}*${POSTFIX_FULL} | sort -V))
        local num_backups_full=${#BACKUPS_FULL[@]}

        if [ "$num_backups_full" -gt "$FULL_BACKUPS_RETENTION" ]; then
            # Calculate the number of backups to delete
            local backups_to_delete=$(($num_backups_full - $FULL_BACKUPS_RETENTION))
            
            # Delete the oldest backups
            for (( i=0; i<$backups_to_delete; i++ )); do
                echo "Deleting old full backup: ${BACKUPS_FULL[$i]}" | tee -a "$TEMP_OUTPUT"
                rm -rf "${BACKUPS_FULL[$i]}"
            done
        fi
    }

    remove_old_inc_backups(){
        local BACKUPS_INC=($(ls -d ${DESTINATION}/${PREFIX}*${POSTFIX_INC} | sort -V))
        local num_backups_inc=${#BACKUPS_INC[@]}
        
        if [ "$num_backups_inc" -gt "$MAX_BACKUPS" ]; then
            # Calculate the number of backups to delete
            local backups_to_delete=$(($num_backups_inc - $MAX_BACKUPS))
            
            # Delete the oldest backups
            for (( i=0; i<$backups_to_delete; i++ )); do
                echo "Deleting old incremental backup: ${BACKUPS_INC[$i]}" | tee -a "$TEMP_OUTPUT"
                rm -rf "${BACKUPS_INC[$i]}"
            done
        fi
    }

    remove_old_full_backups
    remove_old_inc_backups
}

ending() {
    cat "$TEMP_OUTPUT" > "$LOG_FILE_NAME"
    if [ $SUCCESS -eq 1 ]; then
        ending_good
    else
        ending_bad
    fi     
}

ending_good() {
    local caption=$(cat <<EOF
SUCCESS

$BACKUP_DIR
EOF
)
    curl -F chat_id="$CHAT_ID" \
         -F document=@"$LOG_FILE_NAME" \
         -F caption="$caption" \
         "$TELEGRAM_API_URL/sendDocument"
    cp "$LOG_FILE_NAME" "$BACKUP_DIR"
    echo "$TEMP_OUTPUT was copied to: $BACKUP_DIR"
}

ending_bad() {
    curl -F chat_id="$CHAT_ID" \
         -F document=@"$LOG_FILE_NAME" \
         -F caption="Backup failed!" \
         "$TELEGRAM_API_URL/sendDocument"
    
}

clear_temp_files(){
    rm "$TEMP_OUTPUT"
    rm "$LOG_FILE_NAME"
}

BACKUP_STARTED=$TIMESTAMP

set_mode

find_latest_backup   

perform_backup

BACKUP_FINISHED=$(date +"%Y-%m-%d_%H-%M-%S")

manage_backups

final_print | tee -a "$TEMP_OUTPUT"

LOG_FILE_NAME="bkp_${PREFIX}_${TIMESTAMP}_${STATUS}.log"

ending

clear_temp_files
