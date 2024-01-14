#!/bin/bash

# Setup logging
LOGFILE="/var/log/mountscript.log"
exec > >(tee -a ${LOGFILE} )
exec 2> >(tee -a ${LOGFILE} >&2)

SMBV=2.0 # SMB version
DM=10.0.0.5 # External domain
NTFY=10.0.0.4 # ntfy.sh mobile push notifications ip
NTFYPORT=50025 # ntfy.sh mobile push notifications port
PASS=1234 # password
USER=username # username
# mapping of mount points to docker services
declare -A mount_to_service=(
    ["/mnt/Kingston"]="archivebox absonic fancy-ukraine httpdir"
    ["/mnt/G2"]="flaresolverr prowlarr radarr sonarr booksonic wg-delugevpn wg-storm"
)

# Function to check if mount was successful
check_mount() {
    local MOUNTPOINT=$1
    if mountpoint -q $MOUNTPOINT; then
        echo "✅ [SUCCESS] $MOUNTPOINT is mounted."
        # Restart dependent services
        if [[ -n ${mount_to_service[$MOUNTPOINT]} ]]; then
            echo "🔄 Restarting services on $MOUNTPOINT..."
            affected_services=""
            for service in ${mount_to_service[$MOUNTPOINT]}; do
                sudo docker restart $service
                echo "🔄 Docker Restarted Service: $service"
                affected_services+="$service, "
            done
            # Notify about affected services
            if command -v ntfy >/dev/null 2>&1; then
                # ntfy is installed, proceed with sending the message
                curl -d "AutoMountNFS: Restarted services on $MOUNTPOINT: $affected_services" "$NTFY:$NTFYPORT/automount_nfs"
            else
                echo "ntfy is not installed."
                # Handle the case where ntfy is not installed, if necessary
            fi
        fi
    else
        echo "❌ [ERROR] Failed to mount $MOUNTPOINT."
        # Notify using curl
        if command -v ntfy >/dev/null 2>&1; then
            # ntfy is installed, proceed with sending the message
            curl -d "AutoMountNFS: $MOUNTPOINT failed to mount" "$NTFY:$NTFYPORT/automount_nfs"
        else
            echo "ntfy is not installed."
            # Handle the case where ntfy is not installed, if necessary
        fi
    fi
}

# Function to check if file exists and mount if not
mount_drive() {
    local DRIVE=$1
    local MOUNTPOINT=$2
    local CREDENTIALS=$3
    local OPTION=$4
    local UUID="${DRIVE#UUID=}"
    if mountpoint -q "$MOUNTPOINT"; then
        echo "🆗 $MOUNTPOINT is already mounted"
    else
        echo "⭕ $MOUNTPOINT does not exist. Attempting to mount..."
        for i in {1..3}; do
            if [[ $DRIVE == UUID=* ]]; then
                # This is a local drive
                sudo mount -U $UUID $MOUNTPOINT && break || sleep 5
                echo "✅ Mounted drive: 🈁Local: UUID=$UUID to $MOUNTPOINT"

            else
                # This is a network drive
                sudo mount -t cifs $DRIVE $MOUNTPOINT -o $CREDENTIALS,$OPTION && break || sleep 5
                echo "✅ Mounted drive: 📶Remote: $DRIVE to $MOUNTPOINT"
            fi
        done
        check_mount $MOUNTPOINT
    fi
}
# Your credentials
credentials="username=$USER,password=$PASS,nobrl,iocharset=utf8,vers=$SMBV,uid=1000,rw,noperm"

# Array of your drives, drive paths and mount points
declare -A drives=(
    # Network Drives
    ["/mnt/C"]="//$DM/C"                                                                             # C: 1
    ["/mnt/emby/anime/1"]="//$DM/E/Downloads/Torrents/Movies-Shows/Anime"                            # E: 1
    ["/mnt/emby/anime/2"]="//$DM/F/Torrents/Movies-TV/Anime"                                         # F: 1
    ["/mnt/emby/movies/1"]="//$DM/E/Downloads/Torrents/Movies-Shows/Movies"                          # E:   2
    ["/mnt/emby/movies/2"]="//$DM/F/Torrents/Movies-TV/Movies"                                       # F:   2
    ["/mnt/emby/movies/3"]="//$DM/R/Torrents/Movies-TV/Movies"                                       # R: 1
    ["/mnt/emby/tv/1"]="//$DM/E/Downloads/Torrents/Movies-Shows/TV-Shows"                            # E:    3
    ["/mnt/emby/tv/2"]="//$DM/F/Torrents/Movies-TV/TV-Shows"                                         # F:    3
    ["/mnt/emby/tv/3"]="//$DM/R/Torrents/Movies-TV/TV-Shows"                                         # R:   2
    ["/mnt/E"]="//$DM/E"                                                                             # E:      4
    ["/mnt/Zero"]="//$DM/R"                                                                          # R:    3
    ["/mnt/G2"]="//$DM/G2"                                                                           # G: 1
    ["/mnt/Se7en"]="//$DM/J"                                                                         # J: 1
    ["/mnt/Purple"]="//$DM/I"                                                                        # I: 1
    ["/mnt/Jellyfin"]="//$DM/O"                                                                      # O: 1
    # Local Drives
    ["/mnt/Ronin"]="UUID=d9363f2a-dce6-4156-a4f6-97dbc56da0f2"                                       # X: 1
    ["/mnt/Kingston"]="UUID=a85b3ded-84d3-4b24-9cd0-4d3fddc3681a"                                    # Y: 1
    #                                                                                                # Total 17
    #                                                                                                # C E F G I J O R X Y
)

# Mount all drives
for MOUNTPOINT in "${!drives[@]}"; do
    DRIVE="${drives[$MOUNTPOINT]}"
    echo "- Processing drive $DRIVE..."
    mount_drive $DRIVE $MOUNTPOINT $credentials
done
echo "✅ All drives processed"
echo " "
echo "List drives"
echo "ls {/mnt/C,/mnt/emby/anime/1,/mnt/emby/anime/2,/mnt/emby/movies/1,/mnt/emby/movies/2,/mnt/emby/movies/3,/mnt/emby/tv/1,/mnt/emby/tv/2,/mnt/emby/tv/3,/mnt/E,/mnt/Zero/,/mnt/G2,/mnt/Se7en,/mnt/LilithPresser,/mnt/Purple,/mnt/Ronin,/mnt/Kingston}"
echo "❇️ Restart complete"
echo "✳️ Script Execution Complete"
if command -v ntfy >/dev/null 2>&1; then
    # ntfy is installed, proceed with sending the message
    curl -d "AutoMountNFS: Execution complete" "$NTFY:$NTFYPORT/automount_nfs"
    else
        # Handle the case where ntfy is not installed, if necessary
        echo "ntfy is not installed."
fi
