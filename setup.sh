#!/bin/bash

#install weewx and mysql
wget -qO - http://weewx.com/keys.html | sudo apt-key add -
wget -qO - http://weewx.com/apt/weewx.list | sudo tee /etc/apt/sources.list.d/weewx.list
sudo apt-get update
sudo apt-get install weewx python-mysqldb mysql-server -y

read -p "Enter password for new database user weewx: " dbpassword
echo "(Now root password)"
mysql -u root -p -e "CREATE USER 'weewx'@'localhost' IDENTIFIED BY '${dbpassword}'; GRANT ALL PRIVILEGES ON *.* TO 'weewx'@'localhost'; FLUSH PRIVILEGES;"

#disabling ONLY_FULL_GROUP_BY
sed -i 's/sql_mode = ".*"\|\[\(mysqld\)\]\|[ \t]*$//g' /etc/mysql/my.cnf && sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' /etc/mysql/my.cnf
printf "\n[mysqld]\nsql_mode = \"STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION\"\n" >> /etc/mysql/my.cnf
service mysql restart

#changing weewx.conf
sed -i 's/database = archive_sqlite/database = archive_mysql/' /etc/weewx/weewx.conf
wconf_mysql_line=$(cat /etc/weewx/weewx.conf | grep -n "\[\[MySQL\]\]" | grep -Eo '^[^:]+')
ommand="sed -i '${wconf_mysql_line}~1s/password = .*$/password = ${dbpassword}$/' /etc/weewx/weewx.conf"
eval "$command"
service weewx restart

#installing openresty
cd /home
wget https://openresty.org/download/openresty-1.11.2.3.tar.gz
tar -xvf openresty-1.11.2.3.tar.gz
cd openresty-1.11.2.3
apt-get install libreadline-dev libncurses5-dev libpcre3-dev libssl-dev perl make build-essential curl libxslt1-dev libgd-dev libgeoip-dev -y
./configure --with-luajit --with-http_addition_module --with-http_dav_module --with-http_geoip_module --with-http_gzip_static_module --with-http_image_filter_module --with-http_realip_module --with-http_stub_status_module --with-http_ssl_module --with-http_sub_module --with-http_xslt_module --with-ipv6
make install
cd /home
rm -dr openresty-1.11.2.3
rm openresty-1.11.2.3.tar.gz

#cloning git
sudo mkdir /home/amatyr
git clone https://github.com/Zulmamwe/amatyr-mysql.git /home/amatyr

#bootstrap and fa
cd /home/amatyr/static
sudo apt-get install unzip -y
#bootstrap
wget http://getbootstrap.com/2.3.2/assets/bootstrap.zip
unzip bootstrap.zip
rm bootstrap.zip
#fontawesome
wget http://fontawesome.io/assets/font-awesome-4.7.0.zip
unzip font-awesome-4.7.0.zip
mkdir fa
mv font-awesome-4.7.0/* fa/
rm font-awesome-4.7.0.zip
rm -d font-awesome-4.7.0

#setting config json
cp /home/amatyr/etc/config.json.dist /home/amatyr/etc/config.json
read -p "Enter station name: " station_name
read -p "Enter google maps url: " coordinates_url
read -p "Enter url of updating cam image (dont forget http-s): " cam_url
read -p "Enter the year of first weather data: " year

command="sed -i 's/\"password\": \".*\"/\"password\": \"${dbpassword}\"/' /home/amatyr/etc/config.json"
eval "$command"
command="sed -i 's/\"name\": \".*\"/\"name\": \"${station_name}\"/' /home/amatyr/etc/config.json"
eval "$command"
command="sed -i '28s/\"url\": \".*\"/\"url\": \"${coordinates_url}\"/' /home/amatyr/etc/config.json"
eval "$command"
command="sed -i '33s/\"url\": \".*\"/\"url\": \"${cam_url}\"/' /home/amatyr/etc/config.json"
eval "$command"
command="sed -i 's/\"firstyear\": \".*\"/\"firstyear\": \"${year}\"/' /home/amatyr/etc/config.json"
eval "$command"

#setting nginx conf
read -p "Enter server name (domain name, droplet ip, all of them divided by space): " server_name
command="sed -i 's/server_name .*;/server_name ${server_name};/' /home/amatyr/nginx.conf"

/usr/local/openresty/nginx/sbin/nginx -s stop
/usr/local/openresty/nginx/sbin/nginx -c /home/amatyr/nginx.conf
