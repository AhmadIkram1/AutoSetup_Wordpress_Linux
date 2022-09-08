#!/bin/bash
# Author: Ahmad Ikram
# Email: mahmadikram.11@gmail.com
# Date: 08/09/2022
# Description: This script will check if your OS is Debian based or Red Hat Based then
# install and setup wordpress accordingly. It is tested of Centos 7 and Ubuntu 20.04

#  DB Name DB Username and Password
MAINDB="wordpress"
PASSWDDB="admin123"

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "You Should Be root user to run this script"
    exit
fi


#checking if system is debian
apt --help &> /dev/null
if [ $? -eq 0 ]
then
  echo "You are using Debian Based OS"
  echo
  echo "Installing required packages please wait...."
  
  #installing required packages
  sudo apt update
  sudo apt install apache2 \
                 ghostscript \
                 libapache2-mod-php \
                 mysql-server \
                 php \
                 php-bcmath \
                 php-curl \
                 php-imagick \
                 php-intl \
                 php-json \
                 php-mbstring \
                 php-mysql \
                 php-xml \
                 php-zip -y 

  sudo mkdir -p /srv/www
  sudo chown www-data: /srv/www
  echo
  echo "Installing Wordpress...."
  #getting wordpress 
  curl https://wordpress.org/latest.tar.gz | sudo -u www-data tar zx -C /srv/www 
  
  #changing configuration
  cat <<EOF >/etc/apache2/sites-available/wordpress.conf
  <VirtualHost *:80>
    DocumentRoot /srv/www/wordpress
    <Directory /srv/www/wordpress>
        Options FollowSymLinks
        AllowOverride Limit Options FileInfo
        DirectoryIndex index.php
        Require all granted
    </Directory>
    <Directory /srv/www/wordpress/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
EOF

systemctl restart apache2

sudo a2ensite wordpress
sudo a2enmod rewrite
sudo a2dissite 000-default
sudo service apache2 reload

echo
echo "Setting Up Database..."

#creating database
mysql -u root -e "CREATE DATABASE ${MAINDB} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
mysql -u root -e "CREATE USER ${MAINDB}@localhost IDENTIFIED BY '${PASSWDDB}';"
mysql -u root -e "GRANT ALL PRIVILEGES ON ${MAINDB}.* TO '${MAINDB}'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

sudo -u www-data cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/database_name_here/'"$MAINDB"'/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/username_here/'"$MAINDB"'/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/password_here/'"$PASSWDDB"'/' /srv/www/wordpress/wp-config.php
service mysql restart

echo "DB Name: $MAINDB"
echo "DB Username: $MAINDB"
echo "DB Password: $PASSWDDB"
echo
echo "Wordpress Setup Completed Visit Your Host IP"
echo

else

#check if system is red hat
  yum --help &> /dev/null
  if [ $? -eq 0 ]
  then
    echo "Your are using Red Hat Based OS"
    echo
    echo "Installing required packages please wait...."

#installing required packages
yum install httpd php php-common php-mysqlnd php-mbstring php-gd mariadb-server mod_ssl -y 

sed -i ‘s/AllowOverride non/AllowOverride all/g’ /etc/httpd/conf/httpd.conf

chown -R apache:apache /var/www
#chmod 2775 /var/www

#find /var/www -type d -exec sudo chmod 2775 {} \;
#find /var/www -type f -exec sudo chmod 0664 {} \;

systemctl start httpd
systemctl enable httpd
systemctl start mariadb
systemctl enable mariadb

echo
echo "Setting Up Database..."

# database configuration
/usr/bin/mysqladmin -u root password "$PASSWDDB"
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"$PASSWDDB\r\"
expect \"Change the root password?\"
send \"y\r\"
expect \"New password\"
send \"$PASSWDDB\r\"
expect \"Re-enter new password\"
send \"$PASSWDDB\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
echo "$SECURE_MYSQL"

#Creating db user and db
mysql -u root -p$PASSWDDB mysql -e "\
CREATE DATABASE wordpress;
GRANT ALL PRIVILEGES ON *.* TO '$MAINDB'@'localhost' IDENTIFIED BY '$PASSWDDB' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO '$MAINDB'@'%'  IDENTIFIED BY '$PASSWDDB' WITH GRANT OPTION;
FLUSH PRIVILEGES;\
"

echo
echo "Installing and congifuring wordpress please wait..."

mkdir -p /var/www/
pushd /var/www/
yum install wget -y
wget https://wordpress.org/latest.tar.gz 
tar -xzf latest.tar.gz
rm -f latest.tar.gz
chown -R apache:apache wordpress
mv html{,_old}
mv wordpress html
popd

chown -R apache:apache /var/www/html
rpm -Uvh http://vault.centos.org/7.0.1406/extras/x86_64/Packages/epel-release-7-5.noarch.rpm
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
yum --enablerepo=remi,remi-php56 install php php-common -y

yum --enablerepo=remi,remi-php56 install php-cli  php-pear php-pdo php-mysql php-mysqlnd php-pgsql php-sqlite php-gd php-mbstring php-mcrypt php-xml php-simplexml php-curl php-zip -y 

systemctl restart httpd.service

echo
echo "DB Name: $MAINDB"
echo "DB Username: $MAINDB"
echo "DB Password: $PASSWDDB"
echo
echo "Wordpress Setup Completed Visit Your Host IP"
echo

  else 
     echo "Your OS is Not Supported"  
  fi

fi