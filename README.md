# Mastobot
A pair of Bash scripts to divide up a video into chunks—one per caption—and then post them to Mastodon, e.g. as a bot. This is designed to post MP4s, but with some tweaks it can post any asset (e.g. images, audio).

The video processor iterates through each caption in an SRT file and, for each one, saves that clip from the associated video. The Mastodon bot gets a file listing from an S3 bucket, randomly selects one of the files, and posts it to Mastodon.

## Setup

### Video processor

* Prerequisite: a video file that contains captions and an SRT file of those captions
* Ensure that ffmpeg is installed
* Configure `processor.sh` to use the correct filenames for the two files (or name them `video.m4v` and `captions.srt`)

### Mastodon bot

* Ensure that ffmpeg, cURL, and AWS CLI are installed, and that the account is configured to have permission to retrieve files from S3
* Create a new application in your Mastodon account’s settings, giving it permission to create new posts (no other permissions are required), and note the application’s access token
* Put your video clips into a dedicated S3 bucket (or a dedicated directory within an S3 bucket)
* Configure the three variables in the header of `mastobot.sh`: `MASTODON_SERVER`, `MASTODON_TOKEN`, and `S3_BUCKET`
* Create a new cron task to run `mastobot.sh` periodically

## Use
* Run `processor.sh` and `clips/` will be filled up with incrementally numbered files, which must be uploaded to an S3 bucket to be accessible to the bot
* Run `mastobot.sh` and it will post a single video clip to Mastodon
