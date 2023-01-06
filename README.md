# Mastobot
A Bash script to serve as a Mastodon bot. It's created to post MP4s, but with some tweaks it can post any asset (e.g. images).

It gets a file listing from an S3 bucket, randomly selects one of the files, and posts it to Mastodon.

## Setup

* Ensure that cURL and AWS CLI are installed, and that the account is configured to have permission to retrieve files from S3
* Create a new application in your Mastodon account’s settings, giving it permission to create new posts (no other permissions are required), and note the application’s access token
* Put your video clips into a dedicated S3 bucket (or a dedicated directory within an S3 bucket)
* Configure the three variables in the header: `MASTODON_SERVER`, `MASTODON_TOKEN`, and `S3_BUCKET`
* Create a new cron task to run the script periodically

## Use
Run `mastobot.sh` and it will post a single video clip to Mastodon.
