
# Backup Script for Linux Systems

## Overview

This script automates the backup of directories on Linux systems. It supports both full and incremental backups, manages retention of backups, logs all activities, and can send the logs to a Telegram chat.

## Usage

```bash
./backup_script.sh <source> <destination> <prefix> [<max_backups>]
```

### Arguments

- **`<source>`**: The directory to back up.
- **`<destination>`**: The directory where the backups will be stored.
- **`<prefix>`**: A prefix for the backup folder names, used to distinguish different backup sets.
- **`[<max_backups>]`**: Optional. The maximum number of incremental backups to keep. Defaults to 7.

### Example

```bash
./backup_script.sh /path/to/source /path/to/destination my_backup_prefix 5
```

This command will back up the `/path/to/source` directory to `/path/to/destination` with the prefix `my_backup_prefix` and retain up to 5 incremental backups.

## Configuration

### Backup Retention

- **`FULL_BACKUPS_RETENTION`**: The maximum number of full backups to retain (default: 2).
- **`MAX_BACKUPS`**: The maximum number of incremental backups to retain (default: 7).
- The script ensures that the number of backups does not fall below `MIN_BACKUPS` (set to 2).

### Rsync Parameters

- **`BASE_RSYNC_PARAMETERS`**: Customize this to add or remove `rsync` options. The default includes options like `-aAXhvP --delete`.

### Exclude Patterns

- **`EXCLUDES`**: An array of patterns to exclude from the backup. Customize this array to exclude specific directories or files.

### Telegram Notifications

- Set the `CHAT_ID` and `BOT_TOKEN` with your Telegram chat ID and bot token to receive logs via Telegram.

## How It Works

### 1. Mode Selection

The backup mode (full or incremental) is determined by the day of the week:

- By default, a full backup is performed on day 6 (Saturday), and incremental backups are performed on other days.
- You can change the case values in the `set_mode()` function to customize which days perform which backups.

### 2. Finding the Latest Backup

The `find_latest_backup()` function determines the most recent backup to use as a base for incremental backups.

### 3. Performing the Backup

The `perform_backup()` function runs the appropriate `rsync` command to perform either a full or incremental backup. It logs the result and checks if the `rsync` command was successful.

### 4. Backup Management

The `manage_backups()` function deletes old backups if they exceed the specified retention limits.

### 5. Logging and Notifications

- The script logs all activities to a temporary file (`$TEMP_OUTPUT`). At the end of the process, the log is saved and optionally sent to a Telegram chat.
  
### 6. Cleanup

Temporary files are deleted at the end of the script execution.

## Customization

- **Backup Days**: Adjust the `set_mode()` function to change which days of the week perform full backups.
- **Rsync Options**: Modify `BASE_RSYNC_PARAMETERS` and `EXCLUDES` to fit your backup needs.
- **Retention Settings**: Adjust `FULL_BACKUPS_RETENTION` and `MAX_BACKUPS` to manage how many backups you want to keep.

## Error Handling

The script checks if the `rsync` command fails and deletes any incomplete backup directories. Logs are sent to Telegram in case of both success and failure.

## Running the Script

1. **Make the script executable**:

    ```bash
    chmod +x backup_script.sh
    ```

2. **Run the script with the required arguments**:

    ```bash
    ./backup_script.sh /path/to/source /path/to/destination my_backup_prefix 5
    ```
