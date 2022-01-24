# createlecertificate
Bash script to create a host file and SSL certificate using Certbot

# Prerequisites
Need to have certbot installed. For Ubunutu you can follow this guide - https://www.digitalocean.com/community/tutorials/how-to-secure-apache-with-let-s-encrypt-on-ubuntu-16-04

# Installation
1. Create the new file `sudo touch /usr/local/bin/newcert.sh`
2. Copy the contents of newcertificate.sh to newcert.sh `sudo nano newcert.sh` 
3. Change permissions so anyone can use `sudo chmod 700 /usr/local/bin/newcert.sh`

# Usage
`sudo newcert.sh`

It will ask you for the new FQDN and check for the existance of any vhost files matching that name. If it finds one it will exit.
If there are no files it will create a new one in /etc/apache2/sites-enabled/ (configurable) and begin the certification process with certbot

# Enhancement
- Added certificate validation using openssl
- It's now reloading apache instead of restarting (Potential workaround for segmentation fault )
- Added logging for PIDs
- Will now check if certbot account is installed or exists and will use the account automatically 

**Future upgrades**
- Modify the script to check for the contents of all vhost files instead of just the file name
- Check that Apache is responding with the new SSL certificate
- Add a monitor to letsmonitor.org via API
- Option to add monitor to Uptimerobot via API
- Rsync to other servers (via prompt)
- Verify if certbot is installed. Possibly install
- Validate FQDN CNAME record


