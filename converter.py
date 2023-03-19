import csv
from datetime import datetime, time

# Open the SRT file for reading and the CSV file for writing
with open('captions.srt', 'r') as srt_file, open('captions.csv', 'w', newline='') as csv_file:
    csv_writer = csv.writer(csv_file, delimiter=',')

    # Loop through the SRT file, reading four lines at a time
    lines = []
    for line in srt_file:
        if line == "\n":

            # Extract the start and end times and the subtitle text
            number = lines[0]
            start_time, end_time = lines[1].split(' --> ')
            text = ' '.join(lines[2:])

            # Convert the time to seconds
            time_object = datetime.strptime(start_time, "%H:%M:%S,%f").time()
            start_time = time_object.hour * 3600 + time_object.minute * 60 + time_object.second + time_object.microsecond / 1000000.0
            time_object = datetime.strptime(end_time, "%H:%M:%S,%f").time()
            end_time = time_object.hour * 3600 + time_object.minute * 60 + time_object.second + time_object.microsecond / 1000000.0
        
            # Write the data to the CSV file
            csv_writer.writerow([number, start_time, end_time, text])
            lines = []

        else:
            lines.append(line.strip())

# Now read records back out of the CSV file
with open('captions.csv', 'r') as csv_file:

    # Create a reader object
    csv_reader = csv.DictReader(csv_file, fieldnames=['id', 'start_time', 'end_time', 'text'])

    # Create an empty dict to store the rows
    captions = {}

    # Loop through each row in the CSV file
    for row in csv_reader:
        # Append the row to the dict
        id = row['id']
        captions[id] = row

# Create an empty list of clips
clips = {}

# Track how many captions have been added to each clip
caption_count = 0

# Increment through results
for caption in captions.items():
    
    # Go one level deeper (otherwise we just get the ID)
    caption=caption[1]
    
    # If we're not already building a clip
    if(caption_count == 0):
        clip = {}
        clip['id'] = caption['id']
        clip['start_time'] = caption['start_time']
        clip['text'] = caption['text']

    # Set this aside for conditional analysis
    text=caption['text']

    # If the caption text starts with a hyphen, it has dialog from multiple people -- make that
    # the entire clip and continue to the next caption
    if(text[0:1] == '-'):
        clip['id'] = caption['id']
        clip['end_time'] = caption['end_time']
        id=clip['id']
        clips[id] = clip
        caption_count = 0
        continue

    # If the caption text ends with a period, exclamation point, or question mark (but not an
    # ellipsis), this is the end of the clip.
    if (text[-1:] == '.' or text[-1:] == '!' or text[-1:] == '?') and text[-3:] != '...':
        
        if (caption_count == 0):
            clip['end_time'] = caption['end_time']
            id=clip['id']
            clips[id] = clip
            caption_count = 0
            continue
        
        else:
            clip['end_time'] = caption['end_time']
            clip['text'] = clip['text'] + ' ' + caption['text']
            id=clip['id']
            clips[id] = clip
            caption_count = 0
            continue
    
    # If this is just another line, append the text and move on
    if(caption_count > 0):
        clip['text'] = clip['text'] + ' ' + caption['text']
    
    caption_count += 1

# Write the list to a CSV file
with open('clips.csv', 'w', newline='') as file:
    csv_writer = csv.writer(file, delimiter=',')
    
    # Write the headers
    csv_writer.writerow(['id', 'start_time', 'text', 'end_time'])
    
    # Write the values
    for clip in clips.values():
        csv_writer.writerow(clip.values())
