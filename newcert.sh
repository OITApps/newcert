#!/bin/bash

clear

# Set variables
# replace <certbot account ID> with the active ID for the server. SSL generation will fail if not updated. 
account="<certbot account ID>"
certpath="/etc/apache2/sites-enabled/"

#set log file location
log_file="/var/log/oitscript/newcert.log"

#set remote server FQDN's. replace <FQDN> with the server FQDN or IP
#urls must be space separated and enclosed in quotes
#no URL's will disable syncing to that cluster
fac_servers=("<FQDN>")
hosted_servers=("<FQDN>" "<FQDN>")

#set syncuser name to be used for rsync authentication. 
sync_user="certsync"
fac_sync_user="root"

priv_key_loc="/home/$sync_user/.ssh/id_rsa"
fac_priv_key_loc="/$fac_sync_user/.ssh/id_rsa"

############################
#Declaring Global Functions#
############################

#start of the portal fqdn generation function. 
function createFqdn() {
local sslSelection="$1"
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

        # Create configuration file, the content of the conf file is determined by the case selection
        eval $sslSelection

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
        fi
        # Restart Apache
        # Update Feb 22, 2023 - disabled reload of apache to prevent interruption of service.
        # Auto apache reload is dependent on individual CRON jobs.  
        printf "\nApache configuration will reload automatically at 4:00a EST nightly...\n"
        #sudo service apache2 reload
        printf "\nPeforming Apache Config Test..."
        sudo apachectl configtest
}

function createPortal() {
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

}
function createDocs() {
# Create configuration file
        sudo cat <<- EOF > $certpath$filename
<VirtualHost *:443>
        ServerName $fqdn:443
        ServerAlias $fqdn
        ProxyPreserveHost Off
        ProxyAddHeaders On
        ProxyPass / https://voipdocs.helpjuice.com/ nocanon
        ProxyPassReverse / https://voipdocs.helpjuice.com/
        SSLCertificateFile /etc/letsencrypt/live/$fqdn/fullchain.pem
        SSLCertificateKeyFile /etc/letsencrypt/live/$fqdn/privkey.pem
        Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
EOF

}

#Start of Rsyncing files to remote servers. 
function syncCert() {
        #change file permissions to allow for rsyncing
        sudo chmod -R 0655 /etc/letsencrypt/keys/
        sudo chmod -R 0655 /etc/letsencrypt/archive/*/privkey* 

        #rsync new SSL certificate to FAC core servers
        echo "Syncing FAC Servers"
        if [ ${#fac_servers[@]} -ne 0 ]; then
            for fac_server in "${fac_servers[@]}"
            do
                echo $(date) - "Syncing files to $fac_server" | tee -a $log_file
                sudo -u $fac_sync_user rsync -ate "ssh -i $fac_priv_key_loc" ${local_ssl}/ ${fac_sync_user}@${fac_server}:/etc/ssl/ >> /var/log/certsync.log 2>&1 
                sudo -u $fac_sync_user rsync -ate "ssh -i $fac_priv_key_loc" ${local_sites}/ ${fac_sync_user}@${fac_server}:/etc/apache2/sites-enabled >> $log_file 2>&1
                sudo -u $fac_sync_user rsync -ate "ssh -i $fac_priv_key_loc" ${local_LE}/ ${fac_sync_user}@${fac_server}:/etc/letsencrypt >> $log_file 2>&1
                echo $(date) - "Sync to $fac_server complete" | tee -a $log_file
            done
        else
            echo $(date) - "No FAC core servers to sync with." | tee -a $log_file
        fi

        #rsync new SSL certificate to hosted core servers
        echo "Syncing Hosted Servers"
        if [ ${#hosted_servers[@]} -ne 0 ]; then
            for hosted_server in "${hosted_servers[@]}"
            do
                echo $(date) - "Syncing files to $hosted_server" | tee -a $log_file
                sudo -u $sync_user rsync -ate "ssh -i $priv_key_loc" ${local_ssl} ${sync_user}@${hosted_server}:/home/${sync_user}/ >> $log_file 2>&1
                sudo -u $sync_user rsync -ate "ssh -i $priv_key_loc" ${local_sites} ${sync_user}@${hosted_server}:/home/${sync_user} >> $log_file 2>&1
                sudo -u $sync_user rsync -ate "ssh -i $priv_key_loc" ${local_LE} ${sync_user}@${hosted_server}:/home/${sync_user} >> $log_file 2>&1
                echo $(date) - "Sync to $hosted_server complete" | tee -a $log_file
            done
        else
            echo $(date) - "No hosted core servers to sync with." | tee -a $log_file
        fi
}

#Update another server after completion. 
    function update_another() {
                echo "Would you like to create another SSL? <Yes or No> "
        read n
            yes=$(echo n | tr -s '[:upper:]' '[:lower:]' || y)
            if [[  "$n" == "yes" || "$n" == "y"  ]] ; then
                clear
            else
                echo "Exiting Script! "
                exit
            fi
}

####################
#start of SSL create selection
####################
#choose which SSL is to be created. 
        while true; do
        echo -e "Which SSL are you creating? \n"
        echo -e "Please make your selection (<q> to quit)"
        echo -e "1 - WLP Portal SSL"
        echo -e "2 - WLP KB SSL"
        echo -e "q - Quit\n"
        echo "Enter Selection " 

        read ssl
        case $ssl in

#generate portal apache site and SSL
1)
        #generate a portal SSL
        createFqdn "createPortal"
        echo -e "\n"
        #rsync new files to remote servers
        syncCert
        echo -e "\n"       
        #create another SSL
        update_another 
        ;;
2)
        #generate a docs SSL
        createFqdn "createDocs"
        echo -e "\n"
        #rsync new files to remote servers
        syncCert
        echo -e "\n"
        #create another SSL
        update_another 
        ;;
q)
#exit
        echo "Exiting Script! "
        exit
        ;;
*)
#catch all response
        echo "Please select a server "
        ;;
    
        esac
        done



#TODO Function to create UTR or LE monitor
#TODO Report status
