# serverbackup
Backup for centmin server muti-site to both local storage for quick restore and to S3 for long term storage/DR perspective.

iterates through all domains and databases at the account level.

set permissions/users at the account level to perform these operations.  SECURE THIS SCRIPT as it will contain high access rights.
NEVER run this script in a web-accessible area (run above the nginx area)

stores 7 days, moves to weekly, weekly moves to monthly, monthly moves to yearly.

Never grows too large once you hit the 1 year mark in terms of file count.

This works successfully on my Almalinux server running centmin 14 "beta".  Always open to pulls and suggestions.

# Install:

Provision your s3 bucket and secure it correctly.

Install and configure s3cmd tools/command line to your server so that the s3 put and sync commands will function.  Set up of this is out of scope for this repo.  Please refer to the s3cmd project.  https://s3tools.org/s3cmd

Alter and configure backup.sh with your credentials and paths as documented in the file.
Upload to your server such as /backup/backup.sh

Intial run should create local folders.  If not or error occurs, create with write permissions for the executing user such as:

<img width="204" height="214" alt="image" src="https://github.com/user-attachments/assets/cdf530c7-1b50-4091-bc7a-e6198b39eb1b" />

The DB user must have global select rights across acounts if you are backing up the whole server, not just an individual domain account.



Set up a cron job to run the script daily at 3am (or time of your choice)
`sudo crontab -e
0 3 * * * /backup/backup.sh`

If you ran a manual test before setting the cron of the same date, delete the files so the cron runs successfully.

# DR suggestions:
Set up a rule at s3 to replicate across s3 regions (eg, mainbucket is us-east-1, set automation rule to replicate to us-west-1 bucket in your account and set it to glacier to save costs)

# Use of other cloud services
The s3cmd line can be changed to execute any other command line to put or sync to that cloud service.  Follow that service's api and tool kit/sdk.

