#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Change a specific email address of all WordPress users on a VestaCP installation to the same new email address. 

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

#The original email to change.
EMAIL=(some@email.com)
#The new email address.
NEW_EMAIL=(some_other@email.com)

#Path to the VestaCP command line tools.
VESTA_PATH=/usr/local/vesta/bin/
#Wildcard pattern for entering all sites.
DIRS=($1/*/web/*/public_html)
#The time is now.
NOW=$(date +"%m_%d_%Y_%H_%M")

source config.sh

#Logfile
LOGFILE=email-change-${EMAIL}-to-${NEW_EMAILS}-$2-${NOW}.log

function print_user_info()
{
	echo "User: $USER"
}

function print_db_info()
{
	echo "Database name: ${WP_DB_NAME}"
	echo "Database user: ${WP_DB_USER}"
	echo "Database table prefix: ${WP_TABLE_PREFIX}"
}

function print_wp_info()
{
	echo "Admin URL: $WP_ADMIN_URL"
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
	DOMAIN=${DIR_PARTS[3]}
	WP_ADMIN_URL="http://$DOMAIN/wp-admin"

	echo "Domain: $DOMAIN"
	print_user_info

	if [ -f $WP_CONF_FILE ];
	then
		#Get the table prefix.
		WP_DB_NAME=`cat $WP_CONF_FILE | grep DB_NAME | cut -d \' -f 4`
		WP_DB_USER=`cat $WP_CONF_FILE | grep DB_USER | cut -d \' -f 4`
		WP_DB_PASS=`cat $WP_CONF_FILE | grep DB_PASSWORD | cut -d \' -f 4`
		WP_TABLE_PREFIX=`cat $WP_CONF_FILE | grep table_prefix | cut -d \' -f 2`

		print_db_info
		print_wp_info

		echo "WordPress users: "
		echo "SELECT * FROM ${WP_TABLE_PREFIX}users" | mysql -u ${WP_DB_USER} --password=${WP_DB_PASS} ${WP_DB_NAME}

		echo
		for OLD_EMAIL in "${CHANGE_EMAILS[@]}"
		do
			echo 'Changing email from "'${OLD_EMAIL}'" to "'${NEW_EMAIL}'"'
			echo "UPDATE ${WP_TABLE_PREFIX}users SET user_email='${NEW_EMAIL}' WHERE user_email='${OLD_EMAIL}';" | mysql -u ${WP_DB_USER} --password=${WP_DB_PASS} ${WP_DB_NAME}
		done

		echo
		echo "WordPress updated users: "
		echo "SELECT * FROM ${WP_TABLE_PREFIX}users" | mysql -u ${WP_DB_USER} --password=${WP_DB_PASS} ${WP_DB_NAME}
	else
		echo "$DIR contains no WordPress installation"
	fi
	echo
done
