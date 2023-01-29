#!/usr/bin/env bash

# URL of your Mastodon server, including a trailing slash
MASTODON_SERVER="https://botsin.space/"

# Your Mastodon account's access token
MASTODON_TOKEN="ABCDefgh123456789x0x0x0x0x0x0x0x0x0x0x0"

# The S3 bucket where your video clips are stored, including a trailing slash
S3_BUCKET="s3://videobucket.s3.amazonaws.com/directory/"

# Update the file listing 5% of the time
if [ $(( $RANDOM % 20 + 1 )) -eq 1 ]; then
	aws s3 ls ${S3_BUCKET} |grep -E -o "([0-9]+).m4v" > files.txt
fi

# Select a random filename from the list
ENTRY=$(sort -R ${SCRIPT_DIR}/files.txt |head -1)

# Remove any trailing carriage return from the filename
ENTRY=$(echo "$ENTRY" | tr -d '\r')

# Ensure that the filename is a plausible length
if [ ${#ENTRY} -lt 5 ]; then
    exit 1
fi

# Copy the video over from S3
aws s3 cp "${S3_BUCKET}${ENTRY}" "$ENTRY"

# Get the caption text
ffmpeg -i "$ENTRY" -map 0:s:0 test.srt
CAPTION=$(cat caption.srt |tail -n +3 |tr '\n\r' ' ')
rm -f caption.srt

# Upload the video to Mastodon
RESPONSE=$(curl -H "Authorization: Bearer ${MASTODON_TOKEN}" -X POST -H "Content-Type: multipart/form-data" ${MASTODON_SERVER}api/v1/media --form file="@$ENTRY" |grep -E -o "\"id\":\"([0-9]+)\"")

# Strip the media ID response down to the integer; this is in lieu of actually parsing the JSON
MEDIA_ID=$(echo "$RESPONSE" |grep -E -o "[0-9]+")

# If the upload didn't yield a valid media ID, give up
if [ ${#MEDIA_ID} -lt 10 ]; then
    exit 1
fi

# Send the message to Mastodon
curl "$MASTODON_SERVER"/api/v1/statuses -H "Authorization: Bearer ${MASTODON_TOKEN}" -F "status=$CAPTION" -F "media_ids[]=$MEDIA_ID"

# Delete the video file
rm -f "$ENTRY"