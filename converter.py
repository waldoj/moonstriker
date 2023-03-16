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
            print(number, start_time, end_time, text)
            csv_writer.writerow([number, start_time, end_time, text])
            lines = []

        else:
            lines.append(line.strip())

print('Conversion complete')
