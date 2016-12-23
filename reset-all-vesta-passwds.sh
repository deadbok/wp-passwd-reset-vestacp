#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Reset all VestaCP users passwords.

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

#Path to the VestaCP command line tools.
VESTA_PATH=/usr/local/vesta/bin/
#Wildcard pattern for entering all sites.
DIRS=($1/*/web/*/public_html)
#The time is now.
NOW=$(date +"%m_%d_%Y_%H_%M")
#Name of the CSV file for lastpass
CSVFILE=vesta-user-reset-$2-${NOW}.csv
LOGFILE=vesta-user-reset-log-$2-${NOW}.log

VESTA_URL=$2:8083

source config.sh

function print_user_info()
{
	echo "VestaCP URL: ${VESTA_URL}"
	echo "User: $USER"
	echo "New user password: $PASS"
	echo
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
	echo Working directory: $DIR
	echo ------------------------------------------------------------------------------------------------------------------
	#Split the path by '/' to isolate user and domain
	REL_PATH=$(echo "$DIR" | rev | cut -d"/" -f1-5 | rev)
	DIR_PARTS=(${REL_PATH//\// })
	USER=${DIR_PARTS[1]}
	DOMAIN=${DIR_PARTS[3]}

	PASS=($(openssl rand -base64 20))
	if [ $? -ne 0 ]
	then
		echo "ERROR: Failed when creating user password"
	fi

	echo "Domain: $DOMAIN"
	print_user_info

	echo "Changing user password using Vesta."
	${VESTA_PATH}v-change-user-password $USER $PASS
	if [ $? -ne 0 ]
	then
		echo "ERROR: Failed changing user password"
	fi
	#Export CSV data for user
	echo "$2:8083,,$USER,$PASS,$DOMAIN,,$DOMAIN user,CG Admin\\Vesta & FTP users" >> ${CSVFILE}
done

echo "Mailing CSV and log"
for EMAIL in "${EMAILS[@]}"
do
	echo "Mailing: ${EMAIL}"
	template reset_mail.txt | mailx -v -r ${SEND_NAME}  -s "Vesta user password reset information for $2"  -S smtp="${SEND_SMTP}" -S smtp_auth=lgin -S smtp-auth-user="${SEND_NAME}" -S smtp-auth-password="${SEND_PASSWD}" -S smtp-use-starttls -a ${CSVFILE} -a ${LOGFILE} ${EMAIL}
done
