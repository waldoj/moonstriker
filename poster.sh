#!/usr/bin/env bash

set -x

# Shared library: credentials, logging, the failure path, and Mastodon
# transport. See lib/botlib/ and the bot-harness docs.
. "$(dirname "$0")/lib/botlib/core.sh"
. "$(dirname "$0")/lib/botlib/secrets.sh"
. "$(dirname "$0")/lib/botlib/mastodon.sh"

# Get the name of the working directory
cd "$(dirname "$0")" || exit

load_secrets moonstriker
require_secrets MASTODON_SERVER MASTODON_TOKEN S3_BUCKET

# The clip being worked on and the captions extracted from it, both removed
# however this script exits. The original did this inside exit_error; a trap
# covers the success path too, and leaves the shared exit_error free of
# anything bot-specific.
ENTRY=""

function cleanup {
    rm -f "$ENTRY" caption.srt
}

trap cleanup EXIT

# Update the file listing 5% of the time
if [ $(( $RANDOM % 20 + 1 )) -eq 1 ]; then
	aws s3 ls ${S3_BUCKET} |grep -E -o "([0-9]+).m4v" > files.txt
fi

# Store the total number of clips
CLIP_COUNT=$(wc -l files.txt |cut -d " " -f 1)

# Select a clip, making sure that it hasn't been used recently
while :
do

    # Select a random filename from the list
    ENTRY=$(sort -R files.txt |head -1)

    # Remove any trailing carriage return from the filename
    ENTRY=$(echo "$ENTRY" | tr -d '\r')

    # Ensure that the filename is a plausible length
    if [ ${#ENTRY} -lt 5 ]; then
        exit 1
    fi

    # If this clip hasn't been posted in the past 500 times, proceed (otherwise, loop
    # around again)
    CLIP_HISTORY=$(($CLIP_COUNT/2))
    CLIP_HISTORY=$(printf "%.0f" $CLIP_HISTORY)
    HISTORY=$(tail -"$CLIP_HISTORY" history.txt)
    if [[ ! " ${HISTORY[*]} " =~ " ${ENTRY} " ]]; then
        break
    fi    
    
done

# Add this to the history of filenames
echo "$ENTRY" >> history.txt

# Copy the video over from S3
aws s3 cp "${S3_BUCKET}${ENTRY}" "$ENTRY" || exit_error "Could not get video"

# Get the caption text
ffmpeg -i "$ENTRY" -map 0:s:0 caption.srt
CAPTION=$(grep --extended-regexp -v "^[0-9]+\s*$|^[0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3}\s*-->\s*[0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3}\s*$" caption.srt |tr '\n\r' ' ' |sed  -e 's/  / /g')
rm -f caption.srt

# A clip with no usable dialogue posts as video alone. This used to become a
# single space, which was then wrapped in quotes and posted as the literal
# three characters `" "`.
if [ ${#CAPTION} -lt 3 ]; then
    CAPTION=""
fi

# Handle captions that include two people speaking
if [ "${CAPTION:0:2}" == "- " ]; then

    # Split the caption across two lines
    EOL=$'\n'
    CAPTION=${CAPTION/" - "/"$EOL- "}
fi

# Collapse double spaces into one
CAPTION=${CAPTION//"  "/" "}

# Hack off a trailing space, if there is one
if [[ ${CAPTION: -1:1} == " " ]]; then
    CAPTION=${CAPTION:0:-1}
fi

# Upload the video and wait for Mastodon to finish processing it.
#
# The alt text is deliberately empty. The only text this bot has is the clip's
# own dialogue, which already goes in the post body -- repeating it verbatim
# would tell a screen reader nothing it is not already being told.
MEDIA_ID=$(masto_upload_media "$ENTRY" "") \
    || exit_error "Video could not be uploaded"

masto_await_media "$MEDIA_ID" \
    || exit_error "Mastodon never finished processing the video"

# Send the message to Mastodon. The caption is sent as it stands: it used to be
# wrapped in literal quote characters, so a clip with no dialogue posted as the
# three characters `" "` rather than as video alone.
masto_post_status "$CAPTION" "$MEDIA_ID" > /dev/null \
    || exit_error "Posting message to Mastodon failed"

log_info "posted to mastodon media_id=${MEDIA_ID} clip=${ENTRY}"

# The clip and the extracted captions are removed by the EXIT trap

