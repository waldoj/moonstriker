#!/usr/bin/env bash

VIDEO_FILE="video.m4v"
CAPTIONS_FILE="captions.srt"

timestamp() {
    gdate -d "$1" "+%s.%3N"
}

# Get a list of all time ranges, save it as an array
SRTS=()
while IFS= read -r line; do
    SRTS+=( "$line" )
done < <( grep " --> " {$CAPTIONS_FILE} |cut -d " " -f 1,3 )

# Iterate through every caption time range and extract that clip
i=1
for SRT in "${SRTS[@]}"
do
    # Replace commas with periods, for decimal seconds
    SRT=${SRT//,/.}
    
    # Break up the range into a start and a duration
    IFS=' ' read -r -a SRT <<< "$SRT"

    START=$(timestamp "${SRT[0]}")
    END=$(timestamp "${SRT[1]}")
    DURATION=$(echo "$END - $START" |bc)

    # Create the video clip
    ffmpeg -loglevel error -ss "${SRT[0]}" -t "$DURATION" -copyts -i "$VIDEO_FILE" \
        -i "$CAPTIONS_FILE" -ss "${SRT[0]}" -t "$DURATION" -vf \
        subtitles="$CAPTIONS_FILE" -scodec mov_text clips/"$i".m4v
    i=$((1 + i))
done
