#!/bin/bash

clear

# Set variables
# replace <certbot account ID> with the active ID for the server. SSL generation will fail if not updated. 
account="<certbot account ID>"
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
        sudo cat <<- EOF > $certpath$filename
                <VirtualHost *:443>
                ServerName $fqdn:443
                ServerAlias $fqdn
                DocumentRoot /var/www/html/
                SSLCertificateFile /etc/letsencrypt/live/$fqdn/fullchain.pem
                SSLCertificateKeyFile /etc/letsencrypt/live/$fqdn/privkey.pem
                Include /etc/letsencrypt/options-ssl-apache.conf
                </VirtualHost>
                EOF

        # Verify new file was created
        if test  -f $certpath$filename
        then
                printf  "\nNew configuration file created successfully. Beginning certification process...\n"
                # Run Let's Encrypt with the new file
                printf "\nRunning certbot for $fqdn....\n"
                sudo certbot certonly --webroot -w /var/www/html --no-redirect --account $account -d $fqdn

                printf "\nCertbot process complete. Please navigate to $fqdn to verify functionality.\n"
        else
                printf "\nUnable to create configuration file. Contact administrator. Exiting application.\n"
                exit 1
        fi

        # Restart Apache
        # Update Feb 22, 2023 - disabled reload of apache to prevent interruption of service.
        # Auto apache reload is dependent on individual CRON jobs.  
        printf "\nApache configuration will reload automatically at 4:00a EST nightly...\n"
        #sudo service apache2 reload
        printf "\nPeforming Apache Config Test..."
        sudo apachectl configtest
else
        printf "\nYou have not confirmed. Now exiting....\n"
        exit 1
fi

#TODO Function to create UTR or LE monitor
#TODO Report status
#TODO run rsync to other services
