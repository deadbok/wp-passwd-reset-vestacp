#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Reset the password of all WordPress users on all WordPress installations on a VestaCP setup.

#MIT License
#
#Copyright (c) 2016 Martin Bo Kristensen Grønholdt 
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE

#An list of addresses to send the info.
EMAILS=(some@email.com)

#Wildcard pattern for entering all sites.
DIRS=($1/*/web/*/public_html)
#The time is now.
NOW=$(date +"%m_%d_%Y_%H_%M")
LOGFILE=wp-${WP_USER}-log-$2-${NOW}.log
CSVFILE=wp-reset-users-$2-${NOW}.csv

#WordPress user
WP_USER=admin

source config.sh

function print_user_info()
{
	echo "User: $USER"
}
			
function print_db_info()
{
	echo "Database name: ${WP_DB_NAME}"
	echo "Database user: ${WP_DB_USER}"
}

function print_wp_info()
{
	echo "Wordpress backend URL: $WP_ADMIN_URL"
	echo "WordPress user: $WP_USER"
	echo "WordPress database table prefix: ${WP_TABLE_PREFIX}"	
}

#http://stackoverflow.com/a/7633579
function template()
{
    # usage: template file.tpl
    while read -r line ; do
            line=${line//\"/\\\"}
            line=${line//\`/\\\`}
            line=${line//\$/\\\$}
            line=${line//\\\${/\${}
            eval "echo \"$line\""; 
    done < ${1}
}

#http://stackoverflow.com/questions/3173131/redirect-copy-of-stdout-to-log-file-from-within-bash-script-itself/3403786#3403786
# Redirect stdout ( > ) into a named pipe ( >() ) running "tee"
exec > >(tee -i ${LOGFILE})		

#Clear the CSV file
#Add the header
echo "url,type,username,password,hostname,extra,name,folder" > ${CSVFILE}

echo Dirs: ${DIRS[@]}
echo
for DIR in "${DIRS[@]}"
do
	WP_CONF_FILE=$DIR/wp-config.php
	echo Working directory: $DIR
	echo ------------------------------------------------------------------------------------------------------------------
	#Split the path by '/' to isolate user and domain
	REL_PATH=$(echo "$DIR" | rev | cut -d"/" -f1-5 | rev)
	DIR_PARTS=(${REL_PATH//\// })
	USER=${DIR_PARTS[1]}
	if [ $? -ne 0 ]
	then
		echo "ERROR: Getting database user"
	fi
	DOMAIN=${DIR_PARTS[3]}

	WP_ADMIN_URL="http://$DOMAIN/wp-admin"
	WP_PASS=($(openssl rand -base64 12))
		if [ $? -ne 0 ]
	then
		echo "ERROR: Failed when creating WordPress user password"
	fi
	
	echo "Domain: $DOMAIN"
	print_user_info
	print_db_info
	if [ -f $WP_CONF_FILE ];
	then
		WP_DB_NAME=`cat $WP_CONF_FILE | grep DB_NAME | cut -d \' -f 4`
		WP_DB_USER=`cat $WP_CONF_FILE | grep DB_USER | cut -d \' -f 4`
		WP_DB_PASS=`cat $WP_CONF_FILE | grep DB_PASSWORD | cut -d \' -f 4`
		WP_TABLE_PREFIX=`cat $WP_CONF_FILE | grep table_prefix | cut -d \' -f 2`
	
		print_wp_info	
		
		echo
		echo "Changing WordPress secrets"
		python2 change-wp-conf-secrets.py ${WP_CONF_FILE} -s -b
		if [ $? -ne 0 ]
		then
			echo "ERROR: Failed updating $WP_CONF_FILE"
		fi
		
		echo "WordPress users: "
		echo "SELECT * FROM ${WP_TABLE_PREFIX}users" | mysql -u ${WP_DB_USER} --password=${WP_DB_PASS} ${WP_DB_NAME}
		
		USER_EMAILS=($(echo $(echo "SELECT user_email FROM ${WP_TABLE_PREFIX}users" | mysql -u ${WP_DB_USER} --password=${WP_DB_PASS} ${WP_DB_NAME}) | cut -d ' ' -f2-))
		WP_USERS=($(echo $(echo "SELECT user_login FROM ${WP_TABLE_PREFIX}users" | mysql -u ${WP_DB_USER} --password=${WP_DB_PASS} ${WP_DB_NAME}) |  cut -d ' ' -f2-))

		N_USERS=${#WP_USERS[@]}

		echo
		for (( i=0; i<${N_USERS}; i++ ));
		do
			WP_USER=${WP_USERS[$i]}
			if [ "$WP_USER" != "" ];
			then
				WP_PASS=($(openssl rand -base64 12))
				USER_EMAIL=${USER_EMAILS[$i]}
				echo "WordPress user: ${WP_USER}"
				echo "Setting password to: ${WP_PASS}"
				echo "UPDATE ${WP_TABLE_PREFIX}users SET user_pass=md5('${WP_PASS}') WHERE user_login='${WP_USER}';" | mysql -u ${WP_DB_USER} --password=${WP_DB_PASS} ${WP_DB_NAME}

				echo "Mailing credentials..."
				for EMAIL in "${EMAILS[@]}"
				do
					echo "Mailing: ${EMAIL}"
					template user_reset_mail.txt | mutt -s "Password nulstilling for ${WP_USER} på ${DOMAIN}" -- ${EMAIL}
				done
				#Export WordPress user
				echo "${WP_ADMIN_URL},,${WP_USER},$WP_PASS,$DOMAIN,,${WP_USER} on $DOMAIN,WordPress users" >> ${CSVFILE}
				#
				#DO NOT uncomment the next line unless your want to send the WordPress credentials to the email adress of the user.
				#
				echo "Mailing: ${USER_EMAIL}"
				template user_reset_mail.txt | mutt -s "Password nulstilling for ${WP_USER} på ${DOMAIN}" -- ${USER_EMAIL}
			fi
		done				
	
		echo					
		echo "WordPress updated users: "
		echo "SELECT * FROM ${WP_TABLE_PREFIX}users" | mysql -u ${WP_DB_USER} --password=${WP_DB_PASS} ${WP_DB_NAME}				 
	else
		echo "$DIR contains no WordPress installation"
	fi
	echo
done

echo "Mailing CSV and log"
for EMAIL in "${EMAILS[@]}"
do
	echo "Mailing: ${EMAIL}"
	template reset_mail.txt | mutt -s "Password reset information for $2" -a ${CSVFILE} ${LOGFILE} -- ${EMAIL} 
done
