#!/bin/bash

# begin user config

#dbuser used for databases backup
USER="globalmysqldbuser"
#password for the user above
PASSWORD="dbpassword"

#all files backup path
path="/backup/"
dailypath=$path"daily/"
weeklypath=$path"weekly/"
monthlypath=$path"monthly/"

#Email to send notifications to
MAIL="you@yourdomain.com"
#the path where your sites files are
sitespath="/home/nginx/domains/"
siteslist=$(ls $sitespath)

#AWS account bucket
S3BUCKET="s3://yourbucketname"

# end user config 




# begin main script

#log path
statuspath=$path"logs/"
STATUS=$statuspath"statusfile.$datenow.log"
datenow=`date +"%Y%m%d"`
dayofmonth=$(date +%d)
dayofweek=$(date +%u)



echo "Beginning Backup Setup"

# If the directory does not exist, make it please
if [ ! -d $path ]; then
  mkdir -p $path
else
 :
fi

if [ ! -d $dailypath ]; then
  mkdir -p $dailypath
else
 :
fi

if [ ! -d $weeklypath ]; then
  mkdir -p $weeklypath
else
 :
fi

if [ ! -d $monthlypath ]; then
  mkdir -p $monthlypath
else
 :
fi


if [ ! -d $statuspath ]; then
  mkdir -p $statuspath
else
 :
fi

# SITES FILES BACKUP
printf "Backing up these sites:\n$siteslist\n" >> $STATUS
echo "Backing up these sites: $siteslist"

cd $dailypath
var1=0
for site in $siteslist; do
if [ "$site" = 'demodomain.com' ] ; then
	#skip
	printf "\n$site file in skip list, not backuped up\n" >> $STATUS
else
	tar -cf $datenow.$site.tar $sitespath$site
	gzip $datenow.$site.tar
	gunzip -c $datenow.$site.tar.gz | tar t > /dev/null
	successcode=$?
		if [ $successcode -ne 0 ]; then
			printf "\n\n$site ERROR BACKING UP === errorcode = $successcode \n\n" >> $STATUS
			((var1++))
		else
			printf "\n$site Backed up with EXITCODE [ $successcode ]\n" >> $STATUS
		fi
fi
done



# DATABASES BACKUP
DBS="$(mysql -u$USER -p$PASSWORD -Bse 'show databases')"
echo "Database backups initializing..."
echo "$DBS"

errorcounter=0 #innitializing a variable to count errors in mysqldump

#if your db starts with an _ then ignore it this way you can create dbs with _ if you want them ignored
#need to add a list of databases so you can add a database you need to be ignored
for db in $DBS; do
    if [[ "$db" != "information_schema" ]] && [[ "$db" != _* ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "test" ]] ; then
        printf "Dumping database: $db\n"
		        mysqldump --force --opt --user=$USER --password=$PASSWORD --databases $db > $dailypath`date +%Y%m%d`.$db.sql
				exitcode=$?
        gzip $dailypath$datenow.$db.sql
		FILESIZE=$(stat -c%s "$dailypath$datenow.$db.sql.gz")
		printf "$db Backed up with EXITCODE [ $exitcode ] and with size $FILESIZE bytes\n";
		
		#create an if to notify us in case of bad mysqldump
		if [ $exitcode -ne 0 ]; then
			printf "\n\n$db ERROR BACKING UP === errorcode = $exitcode \n\n" >> $STATUS
			((errorcounter++))
		else
			printf "\n$db Backed up with EXITCODE [ $exitcode ] and with size $FILESIZE bytes\n" >> $STATUS
		fi
		
	else
		printf "$db in skip list, not backed up\n" >> $STATUS
	fi
done

# Organize and Cleanup older files if successful
if [ $errorcounter -ne 0 ] || [ $var1 -ne 0 ]; then
	printf "Not deleting or moving anything due to errors in mysqldump\n" >> $STATUS
else
	# move files from daily to weekly if it's sunday
	#echo "Day of week = $dayofweek"
	if [[ $dayofweek -eq 7 ]] ; then
		printf "\nCopy daily to weekly because it's Sunday.\n" >> $STATUS
		cp "$dailypath$datenow".*.sql.gz "$weeklypath" >> $STATUS 2>&1
		if [$? -eq 0 ]; then
			printf "\nCopied $dailypath$datenow sql gz files to weekly\n" >> $STATUS
		fi
		cp "$dailypath$datenow".*.tar.gz "$weeklypath" >> $STATUS 2>&1
		if [$? -eq 0]; then
			printf "\nCopied $dailypath$datenow site gz files to weekly\n" >> $STATUS
		fi

	else
		printf "\nNot Sunday, skipping daily->weekly.\n" >> $STATUS
	fi

	# move files from weekly to monthly if it's the first day of the month.  logic for last day of month is over-complicated with leap year and 28/29/30/31 day variants
	#echo "Day of Month = $dayofmonth"
	if [[ $dayofmonth -eq 1 ]] ; then
		printf "\nCopy Weekly to Monthly because it's the First of the Month.\n" >> $STATUS
		cp "$dailypath$datenow".*.sql.gz "$monthlypath" >> $STATUS 2>&1
		cp "$dailypath$datenow".*.tar.gz "$monthlypath" >> $STATUS 2>&1
		printf "\nCopied $datenow Weekly site gz and DB sql files to Monthly\n" >> $STATUS
	else
		printf "\nNot the first of the month, skipping Weekly to Monthly.\n" >> $STATUS
	fi

	#Cleanup
	find $dailypath -mtime +7 -exec rm {} \;
	printf "\nDaily Files older than 7 days deleted\n" >> $STATUS
	
	find $weeklypath -mtime +31 -exec rm {} \;
	printf "\nWeekly Files older than 31 days deleted\n" >> $STATUS

	find $monthlypath -mtime +366 -exec rm {} \;
	printf "\nMonthly Files older than 1 year deleted\n" >> $STATUS

	find $statuspath -mtime +366 -exec rm {} \;
	printf "\nStatus Files older than 1 year deleted\n" >> $STATUS
	
	# Move to S3
	printf "\nStarting S3 sync\n" >> $STATUS
	#s3cmd   put   --recursive   $path   $S3BUCKET
	# use put if you destory local copy, sync to keep s3 like local and prune old archives
	s3cmd   sync   --recursive   $path   $S3BUCKET
	printf "\nFiles sent to $S3BUCKET \n" >> $STATUS

fi

# Send status email - may have issues with dkim and such if not pre-configured elsewhere as it sends from your server user
printf "** Server $(hostname) **\n$(cat $STATUS)" | mail -s "$(hostname) Backup Results" $MAIL

printf "\nBackup Complete\n" >> $STATUS
