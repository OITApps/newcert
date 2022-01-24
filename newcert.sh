#!/bin/bash
##
## Revision: 1.2
## Revised by: JDG
## Revision Date: Jan 24, 2022
## Change Log
## 01/24/22 
## - Fixed the issue where account is not found when running the certificate on a new server, will now automatically locate the certbot account on the server if certbot is installed.
## - Added confirmation before reloading apache server
## - Added minor logging for the verification and will save logs in /var/log/newcert.log
## - Added certificate validation using openssl
## Perhaps, we can automate this script by having the script check for specific Admin UI, and only generate the certificate if its 
## not yet created and if its not valid.
## We will also have plan on improving the script that will only be executed on one server and will sync the certificate files to the other servers
##
## TO UNINSTALL CERTIFICATE
## sudo rm -rf /etc/apache2/sites-enabled/<fqdn>.conf
## sudo rm -rf /etc/letsencrypt/{live,renewal,archive}/{<fqdn>,<fqdn>.conf}
## sudo service apache2 reload

clear

# Set variables
account_dir="/etc/letsencrypt/accounts/"
live_cert_path="/etc/letsencrypt/live"
account="e87af8285ab91c6d30ae453731febebc" ## If you don't change this account, script will locate it automatically
certpath="/etc/apache2/sites-enabled/"
ts=$(date +"%m-%d-%Y %T %Z")
# We are going to log the results
log_file="/var/log/newcert.log"

## We will check if account exists
account_check=$(find ${account_dir} -type d -name "${account}")
if [ "$account_check" = "" ];then
	echo -e "Account is not found ${account_dir}, locating account..."
	## locate account		
	acme_loc=$(find $account_dir -type d -name "acme-v*")
	if ! [ "$acme_loc" = "" ];then
		## Found acme directory
		## Get the account
		account=$(ls "$acme_loc/directory")
		if [ "account" = "" ];then
			echo -e "ERROR! No account found in $acme_loc"
			exit 1
		else
			echo -e "Using account $account "
		fi
	else
		echo -e "$acme_loc is not found"
		exit 1
	fi	
else
	echo -e "Account ${account} found!"
fi

function check_certificate(){
	if [ "$1" = "" ];then
		echo -e "ERROR! Missing fqdn as argument!"
		echo -e "USAGE: check_certificate pbx.fqdn.com"
	fi

	## Use openssl to verify certificate file
	openssl verify -CAfile "${live_cert_path}/${1}/cert.pem" "${live_cert_path}/${1}/chain.pem"
	if [ $? = 0 ];then
		echo -e "Certificate for $1 is valid"
	else
		echo -e "Certificate for $1 is not valid, openssl error code returned: $?"
		exit 1
	fi
}

printf "Let's get started registering a new cert.\n"
read -p "Please enter the FQDN of the new cert: " fqdn

## Format FQDN
fqdn=$(printf $fqdn | tr "{A-Z}" "{a-z}")

## Confirm intended FQDN
read -p "You have entered $fqdn. Is that correct? [Y|N] " confirm
confirm=$(printf $confirm | tr "{a-z}" "{A-Z}")

## Checking if FQDN is confirmed
if [ $confirm = Y ]
then
	# Call fqdn tests
	printf "\nYou have confirmed $fqdn"

	# Verify if there are any existing Apache configuration files with this name
	printf "\nChecking for any existing configs for $fqdn..."

	filename="${fqdn}.conf"
	if test  -f $certpath$filename
	then
		printf  "\nConfiguration file already exists. Please pick a new FQDN. \nNow exiting...\n"
		echo -e "If you need to delete the old configuration of this certificate, read this doc https://voipdocs.io/en/articles/1533-how-to-remove-letsencrypt-certificate"
		exit 1
	else
		printf "\nNo configuration found. Continuing certification...\n"
	fi

	# Create configuration file
	sudo printf "<VirtualHost *:443>\nServerName $fqdn:443\nServerAlias $fqdn\nDocumentRoot /var/www/html/\n</VirtualHost>" > $certpath$filename

	# Verify new file was created
	if test  -f $certpath$filename
	then
		printf  "\nNew configuration file created successfully. Beginning certification process...\n"
		# Run Let's Encrypt with the new file
		printf "\nRunning certbot for $fqdn....\n"
		sudo certbot --apache --no-redirect --account $account -d $fqdn
		printf "\nCertbot process complete. Ensure you reload apache service for ${fqdn} before checking functionality\n"
	else
		printf "\nUnable to create configuration file. Contact administrator. Exiting application.\n"
		exit 1
	fi

	# Restart Apache	
	read -p "Do you want to reload apache2 now? [Y|N] " confirm
	confirm=$(printf $confirm | tr "{a-z}" "{A-Z}")
	if [ $confirm = Y ];then
		printf "\nListing current processes...\n"
		echo "[${ts}] - Listing current processes" >> $log_file
		ps -ef >> $log_file		
		printf "\nReloading Apache service...\n"
		echo "[${ts}] - Reloading apache2 service" >> $log_file
		sudo service apache2 reload
		if [ $? -eq 0 ]; then
			printf "\nSuccessfully reloaded apache2 service\n"
			echo "[${ts}] - Successfully reloaded apache2 service" >> $log_file			
			## We can implement curl and check the certificate of the website which we need to implement later
			check_certificate $fqdn
			printf "\nYou can now visit https://${fqdn} to confirm!\n"
		else
			printf "\ERROR! Unable to reloaded apache2 service!\n"
			echo "[${ts}] - ERROR! Unable to reloaded apache2 service.  Check the apache or syslog." >> $log_file	
		fi
	else
		printf "\napache2 was not reloadeded! Ensure you reloaded apache2 service for ${fqdn} certificate to be applied.  \n(ie: sudo service apache2 reload)\n"
	fi
else
	printf "\nYou have not confirmed. Now exiting....\n"
	exit 1
fi

#TODO Function to create UTR or LE monitor
#TODO Report status
#TODO run rsync to other services


