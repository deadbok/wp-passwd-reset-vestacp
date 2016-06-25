#!/bin/bash

#An list of addresses to send the info.
EMAILS=(mbkg@commercialgroup.dk)
#Path to the VestaCP command line tools.
VESTA_PATH=/usr/local/vesta/bin/
#Wildcard pattern for entering all sites.
DIRS=($1/*/web/*/public_html)
#The time is now.
NOW=$(date +"%m_%d_%Y")
#Name of the CSV file for lastpass
CSVFILE=users-$2-${NOW}.csv

#WordPress admin user
WP_ADMIN_USER=dev_adhus
WP_ADMIN_EMAIL=info@commercialgroup.dk

#Clear the CSV file
#Add the header
echo "url,type,username,password,hostname,extra,name,folder" > ${CSVFILE}

echo Dirs: ${DIRS[@]}
echo
for DIR in "${DIRS[@]}"
do
	FILE=$DIR/wp-config.php
	if [ -f $FILE ];
	then
		echo Changing passwords and secrets for: $DIR
		#Split the path by '/' to isolate user and domain
		REL_PATH=$(echo "$DIR" | rev | cut -d"/" -f1-5 | rev)
		echo $REL_PATH
		DIR_PARTS=(${REL_PATH//\// })
		USER=${DIR_PARTS[0]}
		DOMAIN=${DIR_PARTS[2]}
		ADMIN_URL="http://$DOMAIN/wp-admin"

		PASS=($(openssl rand -base64 12))
		DB_PASS=($(openssl rand -base64 12))
		WP_ADMIN_PASS=($(openssl rand -base64 12))
		echo "Domain: $DOMAIN"
		echo "Admin URL: $ADMIN_URL"
		echo "VestaCP URL: $2:8083"
		echo "User: $USER"
		echo "New user password: $PASS"
		echo "Database user: ${USER}_db"
		echo "New database password: $DB_PASS"
		echo "WordPress admin user: $WP_ADMIN_USER"
		echo "WordPress admin email: $WP_ADMIN_PASS"
		python2 change-wp-conf-secrets.py ${FILE} -u ${USER}_db -n ${USER}_db -p ${DB_PASS} -s -b
		if [ $? -ne 0 ]
		then
			echo "ERROR: Failed updating $FILE"
		fi
		echo "Changing user and database user using Vesta."
		${VESTA_PATH}v-change-user-password $USER $PASS
		if [ $? -ne 0 ]
		then
			echo "ERROR: Failed changing user password"
		fi
		${VESTA_PATH}v-change-database-password ${USER} ${USER}_db ${DB_PASS}
		if [ $? -ne 0 ]
		then
			echo "ERROR: Failed changing database password"
		fi
		#Export CSV data for user and database
		echo "$2:8083,,$USER,$PASS,$DOMAIN,,,Vesta & FTP" >> ${CSVFILE}
		echo "$2:3306,,${USER}_db,$DB_PASS,$DOMAIN,,,Database" >> ${CSVFILE}
		
		#Get the table prefix.
		head -n -2 ${FILE} > wp-config.php.tmp
		echo "echo \$table_prefix; ?>" >> wp-config.php.tmp
		TABLE_PREFIX=$(php wp-config.php.tmp)
		rm wp-config.php.tmp
		echo "Table prefix: ${TABLE_PREFIX}"	
		
		echo "WordPress users: "
		echo "SELECT * FROM ${TABLE_PREFIX}users" | mysql -u root ${USER}_db
		
		echo "Setting ${WP_ADMIN_USER} email to: ${WP_ADMIN_EMAIL}"
		echo "UPDATE ${TABLE_PREFIX}_users SET user_email=${WP_ADMIN_EMAIL} WHERE user_login='${WP_ADMIN_USER}';" | mysql -u root ${USER}_db

		echo "Setting ${WP_ADMIN_USER} password to: ${WP_ADMIN_PASS}"
		echo "UPDATE ${TABLE_PREFIX}_users SET user_pass=md5('${WP_ADMIN_PASS}') WHERE user_login='${WP_ADMIN_USER}';" | mysql -u root ${USER}_db
				
		echo "WordPress updated users: "
		echo "SELECT * FROM ${TABLE_PREFIX}users" | mysql -u root ${USER}_db
		
		#Export WordPress admin user
		echo "${ADMIN_URL},,${WP_ADMIN_USER},$WP_ADMIN_PASS,$DOMAIN,,,WordPress administrator user" >> ${CSVFILE} 
	else
		echo "$DIR contains no WordPress installation"
	fi
	echo
done
