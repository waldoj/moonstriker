#!/usr/bin/env bash

set -x

# URL of your Mastodon server, without a trailing slash
MASTODON_SERVER="https://botsin.space"

# Your Mastodon account's access token
MASTODON_TOKEN="ABCDefgh123456789x0x0x0x0x0x0x0x0x0x0x0"

# The S3 bucket where your video clips are stored, including a trailing slash
S3_BUCKET="s3://videobucket.amazonaws.com/directory/"

# Get the name of the working directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Define a failure function
function exit_error {
    printf '%s\n' "$1" >&2
    exit "${2-1}"
}

# Update the file listing 5% of the time
if [ $(( $RANDOM % 20 + 1 )) -eq 1 ]; then
	aws s3 ls ${S3_BUCKET} |grep -E -o "([0-9]+).m4v" > files.txt
fi

# Select a random filename from the list
ENTRY=$(sort -R "${SCRIPT_DIR}"/files.txt |head -1)

# Remove any trailing carriage return from the filename
ENTRY=$(echo "$ENTRY" | tr -d '\r')

# Ensure that the filename is a plausible length
if [ ${#ENTRY} -lt 5 ]; then
    exit 1
fi

# Copy the video over from S3
aws s3 cp "${S3_BUCKET}${ENTRY}" "$ENTRY" || exit_error "Could not get video"

# Get the caption text
ffmpeg -i "$ENTRY" -map 0:s:0 caption.srt
CAPTION=$(tail -n +3 "${SCRIPT_DIR}"/caption.srt |tr '\n\r' ' ')
rm -f "${SCRIPT_DIR}"/caption.srt

# If the caption text is a fragment, just make it blank
if [ ${#CAPTION} -lt 3 ]; then
    CAPTION=" "
fi

# Handle captions that include two people speaking
if [ "${CAPTION:0:2}" == "- " ]; then
    EOL=$'\n'
    CAPTION=${CAPTION/" - "/"$EOL- "}
fi

# Collapse double spaces into one
CAPTION=${CAPTION//"  "/" "}

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
rm -f "$SCRIPT_DIR"/"$ENTRY"
