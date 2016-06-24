#!/bin/bash

EMAILS=(mbkg@commercialgroup.dk)

DIRS=($1/*/web/*/public_html)
for DIR in "${DIRS[@]}"
do
	FILE=$DIR/wp-config.php
	if [ -f $FILE ];
	then
		echo "Changing passwords and secrets for: $FILE"
		#Split the path by '/' to isolate user and domain
		REL_PATH=$(echo "$DIR" | rev | cut -d"/" -f1-5 | rev)
		echo $REL_PATH
		DIR_PARTS=(${REL_PATH//\// })
		USER=${DIR_PARTS[0]}
		DOMAIN=${DIR_PARTS[2]}
		ADMIN_URL="http://$DOMAIN/wp-admin"

		PASS=($(openssl rand -base64 12))
		DB_PASS=($(openssl rand -base64 12))
		echo "Domain: $DOMAIN"
		echo "Admin URL: $ADMIN_URL"
		echo "VestaCP URL: $2"
		echo "User: $USER"
		echo "New user password: $PASS"
		echo "New database password: $DB_PASS"
		python2 change-wp-conf-secrets.py ${FILE} -u ${USER}_db -n ${USER}_db -p ${DB_PASS} -s -b
		if [ $? -ne 0 ]
		then
			echo "ERROR: Failed updating $FILE"
		fi
		echo "Changing user and database user using Vesta."
		v-change-user-password $USER $PASS
		if [ $? -ne 0 ]
		then
			echo "ERROR: Failed changing user password"
		fi
		v-change-database-password ${USER}_db $DB_PASS
		if [ $? -ne 0 ]
		then
			echo "ERROR: Failed changing database password"
		fi
		
		
	else
		echo "$DIR contains no WordPress installation"
	fi
	echo
done

