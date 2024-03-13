#!/usr/bin/env bash

set -x

VIDEO_FILE="video.mp4"
CAPTIONS_FILE="captions.srt"
CLIPS_FILE="clips.csv"

# Iterate through every row in the CSV file, getting the start and end timestamps for each
csvcut -c 2,4 "$CLIPS_FILE" |while read -r row
do
    
    IFS=$',' read -ra columns <<< "$row"
    
    DURATION=$(echo "${columns[1]} - ${columns[0]}" |bc)

    # Create the video clip
    ffmpeg -nostdin -loglevel error -ss "${columns[0]}" -t "$DURATION" -copyts -i "$VIDEO_FILE" \
        -i "$CAPTIONS_FILE" -ss "${columns[0]}" -t "$DURATION" -vf \
        subtitles="$CAPTIONS_FILE" -scodec mov_text clips/"$i".m4v
    i=$((1 + i))

done
