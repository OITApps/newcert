# createlecertificate
Bash script to create a host file and SSL certificate using Certbot

# Prerequisites
Need to have certbot installed. For Ubunutu you can follow this guide - https://www.digitalocean.com/community/tutorials/how-to-secure-apache-with-let-s-encrypt-on-ubuntu-16-04

Download file to /usr/local/bin
chmod 700 filename so everyone can use
Must be run with sudo

**IMPORTANT**
Replace the account ID in the top block. You can find your account ID from the below link
https://letsencrypt.org/docs/account-id/

Run the file and it will ask you for the new FQDN
It will check for the existance of any vhost files matching that name. If it finds one it will exit.
If there are no files it will create a new one in /etc/apache2/sites-enabled/ (configurable) and begin the certification process with certbot

**Future upgrades**
- Modify the script to check for the contents of all vhost files instead of just the file name
- Check that Apache is responding with the new SSL certificate
- Add a monitor to letsmonitor.org via API
- Option to add monitor to Uptimerobot via API
- Rsync to other servers (via prompt)

