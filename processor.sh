#!/usr/bin/env bash

VIDEO_FILE="video.m4v"
CAPTIONS_FILE="captions.srt"
CLIPS_FILE="clips.csv"

timestamp() {
    gdate -d "$1" "+%s.%3N"
}

# Iterate through every row in the CSV file, getting the start and end timestamps for each
csvcut -c 2,4 "$CLIPS_FILE" |while read -r row
do
    
    IFS=$'\t' read -ra columns <<< "$row"
    
    START=$(timestamp "${columns[0]}")
    END=$(timestamp "${columns[1]}")
    DURATION=$(echo "$END - $START" |bc)

    # Create the video clip
    ffmpeg -nostdin -loglevel error -ss "${SRT[0]}" -t "$DURATION" -copyts -i "$VIDEO_FILE" \
        -i "$CAPTIONS_FILE" -ss "${SRT[0]}" -t "$DURATION" -vf \
        subtitles="$CAPTIONS_FILE" -scodec mov_text clips/"$i".m4v
    i=$((1 + i))

done
