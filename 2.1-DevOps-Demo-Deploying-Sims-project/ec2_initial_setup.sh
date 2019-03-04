#!/bin/bash

# run this script on sshing into the server
# ssh root@servers_public_IP "sudo bash -s" -- < /path/to/script/file

# set options and positional parameters
# -e exit the shell immediately if a command fails or returns an exit status value > 0
# -u when expand a variable that is not set, exit immediately write a message to standard error
# -o write current settings of the options to standard output in an unspecified format.

set -euo pipefail 

########################
### VARIABLES        ###
########################

DOMAIN='app.sekayasin-testing.tk'
NGINX_DOC_ROOT='app'
NGINX_DOC_ROOT_PATH='/var/www/html/app'
USER='sekayasin'
EMAIL='sekayasin@gmail.com'
REMOTE_REPO_URL='https://github.com/andela/ah-frontend-zeus.git'
LOCAL_REPO_DIR='ah-frontend-zeus'
API_URL="API_URL=https://zeus-staging.herokuapp.com/api"


fixLocaleSettings() {
    echo "------------------------------------------------"
    echo " Fix locales settings                           "
    echo "------------------------------------------------"
    export LC_ALL="en_US.UTF-8"
    export LC_CTYPE="en_US.UTF-8"
    sudo dpkg-reconfigure locales --frontend noninteractive
}

initalServerUpdate() {
    echo "------------------------------------------------"
    echo " Update server                                  "
    echo "------------------------------------------------"
    sudo apt update
    sudo apt upgrade -y
}

initialPackageInstallation() {
    echo "----------------------------------------------------------------------------------------"
    echo " Installing all necessary software packages, python3, nginx, curl, postgresql, nodjes   "
    echo "----------------------------------------------------------------------------------------"
    sudo apt install python3-pip python3-dev libpq-dev postgresql postgresql-contrib nginx curl -y
}

installNodejs() {
    echo "------------------------------------------------"
    echo " Installing Nodejs and yarn                     "
    echo "------------------------------------------------"
    curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
    sudo apt -y install nodejs
    sudo apt -y install libtool pkg-config build-essential autoconf automake
    sudo npm i yarn -g
}

installCerbot() {
    echo "-----------------------------------------------"
    echo " Install certbot                               "
    echo "-----------------------------------------------"
    sudo apt -y install software-properties-common
    sudo add-apt-repository universe
    sudo add-apt-repository ppa:certbot/certbot -y
    sudo apt update
    sudo apt -y install certbot python-certbot-nginx 
}


configureFirewall() {
    # Add exception for SSH and then enable UFW firewall

    echo "-----------------------------------------------"
    echo " Configure firewall                            "
    echo "-----------------------------------------------"
    sudo ufw allow OpenSSH
    sudo ufw allow 80
    sudo ufw allow 443
    sudo ufw allow in 443/tcp comment "https: for certbot"
    sudo ufw allow 'Nginx HTTP'
    sudo ufw --force enable
    sudo ufw status
}

cloneProjectRepo() {
    # clone the project repo
    echo "-----------------------------------------------"
    echo " clone project repo and install dependencies   "
    echo "-----------------------------------------------"
    if [ -d $LOCAL_REPO_DIR ]; then
        echo "Directory $LOCAL_REPO_DIR already exists, cleaning..."
        sudo rm -fr $LOCAL_REPO_DIR
        git clone $REMOTE_REPO_URL
    else 
        git clone $REMOTE_REPO_URL
    fi
    echo $API_URL > $LOCAL_REPO_DIR/.env
}

installProjectDependencies() {
    # install dependencies
    cd $LOCAL_REPO_DIR
    echo "--------------------------------------------"
    echo " install project dependencies               "
    echo "--------------------------------------------"
    sudo yarn
    sudo yarn build
    
    cd /var/www/html 

    if [ -d ${NGINX_DOC_ROOT} ]; then
        echo "Nginx server block Document root ${NGINX_DOC_ROOT} exists, cleaning..."
        sudo rm -fr ${NGINX_DOC_ROOT_PATH}
        sudo mkdir ${NGINX_DOC_ROOT_PATH}
    else
        sudo mkdir ${NGINX_DOC_ROOT_PATH}
    fi
    
    cd ~/$LOCAL_REPO_DIR
    sudo cp dist/* ${NGINX_DOC_ROOT_PATH}/.
}


configureNginx() {
    sudo systemctl enable nginx
    sudo systemctl start nginx

    # copy the default nginx configs to the new server block to config
    sudo cp /etc/nginx/sites-enabled/default /etc/nginx/conf.d/${NGINX_DOC_ROOT}.conf

    # remove all the comments and emptylines in the new server block config file
    sudo sed -i 's/#.*$//g;/^[[:space:]]*$/d' /etc/nginx/conf.d/${NGINX_DOC_ROOT}.conf

    # Remove default_server in the new server block config file
    sudo sed -i 's/ default_server;/;/g' /etc/nginx/conf.d/${NGINX_DOC_ROOT}.conf

    # Edit server block doc root path 
    sudo sed -i 's|root /var/www/html;|root /var/www/html/app;|g' /etc/nginx/conf.d/${NGINX_DOC_ROOT}.conf

    # Edit to add the domain to the server block configuration file
    sudo sed -i 's|server_name _;|server_name app.sekayasin-testing.tk www.app.sekayasin-testing.tk;|g' /etc/nginx/conf.d/${NGINX_DOC_ROOT}.conf
    
    sudo nginx -t
    sudo systemctl restart nginx
}

configureCertbot() {
    sudo certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} -n --agree-tos -m ${EMAIL} --redirect --expand
    sudo systemctl restart nginx
}

cleanUp() {

    cd ~

    if [ -d $LOCAL_REPO_DIR ]; then
        echo "Directory $LOCAL_REPO_DIR exists. Removing the project dir to save diskspace..."
        sudo rm -fr $LOCAL_REPO_DIR
    else 
        echo "Directory $LOCAL_REPO_DIR doesnot exists"
    fi
}

main() {
    initalServerUpdate
    initialPackageInstallation
    installNodejs
    installCerbot
    configureFirewall
    cloneProjectRepo
    installProjectDependencies
    configureNginx
    configureCertbot
    cleanUp
    echo "-----------------------------------------------"
    echo " Done                                          "
    echo "-----------------------------------------------"
}

main
