#!/bin/bash

clear

# Set variables
certpath="/etc/apache2/sites-enabled/"


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
                exit 1
        else
                printf "\nNo configuration found. Continuing certification...\n"
        fi

        # Create configuration file
        sudo printf "<VirtualHost *:443>\nServerName $fqdn:443\nServerAlias $fqdn\nDocumentRoot /var/www/html/\n</VirtualHost>" >  $certpath$filename

        # Verify new file was created
        if test  -f $certpath$filename
        then
                printf  "\nNew configuration file created successfully. Beginning certification process...\n"
                # Run Let's Encrypt with the new file
                printf "\nRunning certbot for $fqdn....\n"
                sudo certbot --apache --no-redirect -d $fqdn

                printf "\nCertbot process complete. Please navigate to $fqdn to verify functionality.\n"
        else
                printf "\nUnable to create configuration file. Contact administrator. Exiting application.\n"
                exit 1
        fi
else
        printf "\nYou have not confirmed. Now exiting....\n"
        exit 1
fi
