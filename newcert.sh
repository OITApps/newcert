#!/bin/bash

clear

# Set variables
# replace <certbot account ID> with the active ID for the server. SSL generation will fail if not updated. 
account="<certbot account ID>"
certpath="/etc/apache2/sites-enabled/"

#sync variables
#set locations of files to be synced
local_ssl="/etc/ssl" # local SSL files
local_sites="/etc/apache2/sites-enabled" # Apache Site
local_LE="/etc/letsencrypt" # local SSL files

#set remote server FQDN's.
#urls must be space separated and enclosed in quotes. replace <server 1> and <server 2> with the respective servers IP or FQDN
#no URL's will disable syncing to that cluster
fac_servers=("<server 1>" "<server 2>")
hosted_servers=()

#set syncuser name to be used for rsync authentication. Replace <rsync user> with the user to be used for authenticating the rsync 
sync_user="<rsync user>"

priv_key_loc="/home/$sync_user/.ssh/id_rsa"

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
		AllowEncodedSlashes On
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

        #change file permissions to allow for rsyncing
        sudo chmod -R 0650 /etc/letsencrypt/keys/
        sudo chmod -R 0650 /etc/letsencrypt/archive/$fqdn/privkey*  

        #rsync new SSL certificate to FAC core servers
        echo "Syncing FAC Servers"
        if [ ${#fac_servers[@]} -ne 0 ]; then
            for fac_server in "${fac_servers[@]}"
            do
                echo "Syncing files to $fac_server"
                sudo -u $sync_user rsync -ate "ssh -i $priv_key_loc" ${local_ssl} ${sync_user}@${fac_server}:/etc/ssl/
		sudo -u $sync_user rsync -ate "ssh -i $priv_key_loc" ${local_sites} ${sync_user}@${fac_server}:/etc/apache2/sites-enabled
                sudo -u $sync_user rsync -ate "ssh -i $priv_key_loc" ${local_LE} ${sync_user}@${fac_server}:/etc/letsencrypt
                echo "Sync to $fac_server complete"
            done
        else
            echo "No FAC core servers to sync with."
        fi

        #rsync new SSL certificate to hosted core servers
        echo "Syncing Hosted Servers"
        if [ ${#hosted_servers[@]} -ne 0 ]; then
            for hosted_server in "${hosted_servers[@]}"
            do
                echo "Syncing files to $hosted_server"
                sudo -u $sync_user rsync -ate "ssh -i $priv_key_loc" ${local_ssl} ${sync_user}@${hosted_server}:/home/${sync_user}/
                sudo -u $sync_user rsync -ate "ssh -i $priv_key_loc" ${local_sites} ${sync_user}@${hosted_server}:/home/${sync_user}
                sudo -u $sync_user rsync -ate "ssh -i $priv_key_loc" ${local_LE} ${sync_user}@${hosted_server}:/home/${sync_user}
                echo "Sync to $hosted_server complete"
            done
        else
            echo "No hosted core servers to sync with."
        fi

        # Restart Apache
        # Update Feb 22, 2023 - disabled reload of apache to prevent interruption of service.
        # Auto apache reload is dependent on individual CRON jobs.  
        printf "\nApache configuration will reload automatically at 4:00a EST nightly...\n"
        #sudo service apache2 reload
        printf "\nPeforming Apache Config Test on local server..."
        sudo apachectl configtest
else
        printf "\nYou have not confirmed. Now exiting....\n"
        exit 1
fi

#TODO Function to create UTR or LE monitor
#TODO Report status
