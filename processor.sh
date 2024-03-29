#!/usr/bin/env bash

set -x

VIDEO_FILE="video.mp4"
CAPTIONS_FILE="captions.srt"
CLIPS_FILE="clips.csv"

mkdir -p clips

# Iterate through every row in the CSV file, getting the start and end timestamps for each
csvcut -c 2,4 "$CLIPS_FILE" |while read -r row
do
    
    IFS=$',' read -ra columns <<< "$row"
    
    DURATION=$(echo "${columns[1]} - ${columns[0]}" |bc)
    # ffmpeg insists on a leading 0 for periods less than 1 second
    if (( $(echo "$DURATION < 1" | bc) )); then
        DURATION="0$DURATION"
    fi

    # Create the video clip
    ffmpeg -nostdin -loglevel error -i "$VIDEO_FILE" -ss "${columns[0]}" -t "$DURATION" \
        -vf "subtitles=$CAPTIONS_FILE" -c:v libx264 -c:a aac clips/"$i".m4v
    i=$((1 + i))

done
