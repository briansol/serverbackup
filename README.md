# serverbackup
Backup for centmin server muti-site to S3

This works successfully on my Almalinux server running centmin 14 "beta".

Install:
Alter and configure backup.sh with your credentials and paths as documented in the file.
Upload to your server such as /backup

Intial run should create local folders.  If not, create with write perms as:
<img width="204" height="214" alt="image" src="https://github.com/user-attachments/assets/cdf530c7-1b50-4091-bc7a-e6198b39eb1b" />

The DB user must have global select rights across acounts if you are backing up the whole server, not just an individual domain account.

Provision your s3 bucket and, secure it correctly, and install and configure s3cmd tools/command line to your server so that the s3 put and sync commands will function.  Set up of this is out of scope for this repo.  please refer to the s3cmd project.  https://s3tools.org/s3cmd

Set up a cron job to run the script daily at 3am with 
`sudo crontab -e
0 3 * * * /backup/backup.sh`

