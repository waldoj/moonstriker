#!/usr/bin/env bash

set -x

# URL of your Mastodon server, without a trailing slash
MASTODON_SERVER="https://botsin.space"

# Your Mastodon account's access token
MASTODON_TOKEN="ABCDefgh123456789x0x0x0x0x0x0x0x0x0x0x0"

# The S3 bucket where your video clips are stored, including a trailing slash
S3_BUCKET="s3://videobucket.amazonaws.com/directory/"

# Define a failure function
function exit_error {
    printf '%s\n' "$1" >&2
    rm -f "$ENTRY"
    rm -f caption.srt
    exit "${2-1}"
}

# Copy the video over from S3
function get_video {
    aws s3 cp "${S3_BUCKET}${ENTRY}" "$ENTRY" || return 1
    return 0
}

# Add the clip to the history of filenames
function add_to_history {
    echo "$ENTRY" >> history.txt
    return 0
}

# Store the total number of clips
function get_clip_count {
    wc -l files.txt |cut -d " " -f 1
    return 0
}

# Update the file listing 5% of the time, or generate it if it doesn't exist
function update_file_list {
    if [ ! -f ./files.txt ] || [ $(( RANDOM % 20 + 1 )) -eq 1 ]; then
        aws s3 ls ${S3_BUCKET} |grep -E -o "([0-9]+).m4v" > files.txt
        if [ $? -gt 0 ]; then
            exit_error "Could not update file listing"
        fi
    fi
    return 0
}

# Select a clip, making sure that it hasn't been used recently
function select_clip {
    while :
    do

        # Select a random filename from the list
        ENTRY=$(sort -R files.txt |head -1)

        # Remove any trailing carriage return from the filename
        ENTRY=$(echo "$ENTRY" | tr -d '\r')

        # Ensure that the filename is a plausible length
        if [ ${#ENTRY} -lt 5 ]; then
            exit_error "Filename is too short"
        fi

        # Divide the total number of clips in half (n clips), and if this proposed clip hasn't been
        # posted in the last n times, then proceed (otherwise, loop around again)
        CLIP_HISTORY=$((CLIP_COUNT/2))
        CLIP_HISTORY=$(printf "%.0f" $CLIP_HISTORY)
        HISTORY=$(tail -"$CLIP_HISTORY" history.txt)
        if [[ ! " ${HISTORY[*]} " =~ " ${ENTRY} " ]]; then
            return 0
        fi

    done
}

# Get the name of the working directory
cd "$(dirname "$0")" || exit

# Update the file listing
update_file_list

# Store the total number of clips
CLIP_COUNT=get_clip_count

# Select a clip
select_clip

# Copy the video over from S3
get_video
if [[ $? == 1 ]]; then
    exit_error "Could not get video"
fi

# Add this clip's filename to the history
add_to_history

# Get the caption text
ffmpeg -i "$ENTRY" -map 0:s:0 caption.srt
CAPTION=$(grep --extended-regexp -v "([,:0-9> -]+)$" caption.srt |tr '\n\r' ' ' |sed  -e 's/  / /g')
rm -f caption.srt

# If the caption text is a fragment, just make it blank
if [ ${#CAPTION} -lt 3 ]; then
    CAPTION=" "
fi

# Handle captions that include two people speaking
if [ "${CAPTION:0:2}" == "- " ]; then

    # Split the caption across two lines
    EOL=$'\n'
    CAPTION=${CAPTION/" - "/"$EOL- "}

    # Quote each line separately
    CAPTION=${CAPTION//'"'/''}
    CAPTION=${CAPTION//'- '/'- "'}
    CAPTION=${CAPTION//"$EOL"/'"' $EOL}
    CAPTION=$CAPTION\"
fi

# Collapse double spaces into one
CAPTION=${CAPTION//"  "/" "}

# Hack off a trailing space, if there is one
if [[ ${CAPTION: -1:1} == " " ]]; then
    CAPTION=${CAPTION:0:-1}
fi

# Escape double quotes for cURL
CAPTION=${CAPTION//'"'/'\"'}

# Upload the video to Mastodon
RESPONSE=$(curl -H "Authorization: Bearer ${MASTODON_TOKEN}" -X POST -H "Content-Type: multipart/form-data" ${MASTODON_SERVER}/api/v1/media --form file="@$ENTRY" |grep -E -o "\"id\":\"([0-9]+)\"")
RESULT=$?
if [ "$RESULT" -ne 0 ]; then
    exit_error "Video could not be uploaded"
fi

# Strip the media ID response down to the integer; this is in lieu of actually parsing the JSON
MEDIA_ID=$(echo "$RESPONSE" |grep -E -o "[0-9]+")

# If the upload didn't yield a valid media ID, give up
if [ ${#MEDIA_ID} -lt 10 ]; then
    exit_error "Video upload didn’t return a valid media ID"
fi

# Send the message to Mastodon
curl "$MASTODON_SERVER"/api/v1/statuses -H "Authorization: Bearer ${MASTODON_TOKEN}" -F "status=\"${CAPTION}\"" -F "media_ids[]=${MEDIA_ID}"

RESULT=$?
if [ "$RESULT" -ne 0 ]; then
    exit_error "Posting message to Mastodon failed"
fi

# Delete the video file
rm -f "$ENTRY"
