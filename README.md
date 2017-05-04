# AmatYr

AmatYr is a personal weather station display software project.

The software is a modern HTML5 "single page app" using JavaScript to fetch data from SQL via JSON from Postgresql + Lua backend. Then the data is transformed into pretty visualizations by the brilliant (D3.js)[http://d3js.org] library, giving the data life!

Primary goal of the project is bringing modern and responsive design, suitable for desktop, tablet and mobile-sized screens. A secondary goal is just playing with new technology because it's fun :-) And I guess a goal is to display some pretty graphs and such for local weather!

### About this git
I'm not the creator of amatyr, i just changed some things to work without custom patches and other crutches. You can update anything to newer version freely (except bootstrap if you dont want to change classes in thml pages, if you do - please send me updated version and i will add it here =D) and everything should still work.

### Frontend Components

-    D3 js
-    jQuery
-    jQuery.timeago
-    Rivets js
-    Watch js
-    Path js 
-    Wind rose chart from [Windhistory.com](http://windhistory.com/about.html)
-    Bootstrap css + js
-    Cal-Heatpmap from Wan Qi Chen <http://kamisama.github.io/cal-heatmap/>


### Backend Components

-   Openresty (nginx + luajit)
-   MySQL


### Installation

1. Install weewx

    > wget -qO - http://weewx.com/keys.html | sudo apt-key add -  
    wget -qO - http://weewx.com/apt/weewx.list | sudo tee /etc/apt/sources.list.d/weewx.list  
    sudo apt-get update  
    sudo apt-get install weewx python-mysqldb

2. Install mysql

    dont forget to change 'password' to actual password
    > sudo apt-get install mysql-server  
    mysql -u root -p -e "CREATE USER 'weewx'@'localhost' IDENTIFIED BY 'password'; GRANT ALL PRIVILEGES ON *.* TO 'weewx'@'localhost'; FLUSH PRIVILEGES;" 
    
    disabling ONLY_FULL_GROUP_BY  
    add this to the end of the file /etc/mysql/my.cnf  
    > [mysqld]  
    sql_mode = "STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"  
    
    now restart mysql  
    > service mysql restart

3. Change weewx.conf

    > nano /etc/weewx/weewx.conf

    change weewx settings as you like  
    here is only required changes:

    first we need to change [[wx_binding]] section  
    >database = archive_sqlite  
    to  
    database = archive_mysql

    now in [DatabaseTypes] [[MySQL]] section
    >change password to the user you just created in mysql (no quotes)  
    password = password

    after this restart weewx
    >service weewx restart

4. Install openresty

    > wget https://openresty.org/download/openresty-1.11.2.3.tar.gz  
    tar -xvf openresty-1.11.2.3.tar.gz  
    cd openresty-1.11.2.3  

    main openresty prerequisites  
    > apt-get install libreadline-dev libncurses5-dev libpcre3-dev libssl-dev perl make build-essential curl
    
    prerequisites for this setup
    >apt-get install libxslt1-dev libgd-dev libgeoip-dev

    configure and install
    >./configure --with-luajit  --with-http_addition_module --with-http_dav_module --with-http_geoip_module --with-http_gzip_static_module --with-http_image_filter_module --with-http_realip_module --with-http_stub_status_module --with-http_ssl_module --with-http_sub_module --with-http_xslt_module --with-ipv6  
    make install

    remove sources
    >cd /home  
    rm -dr openresty-1.11.2.3  
    rm openresty-1.11.2.3.tar.gz  

5. Clone git and edit configs

    >sudo mkdir /home/amatyr  
    git clone https://github.com/Zulmamwe/amatyr-mysql.git /home/amatyr

    download bootstrap and fontawesome  
    (bootstrap is old, im too lazy to rewrite this code)  
    (more important - it's working so i dont bother)
    >cd /home/amatyr/static  
    sudo apt-get install unzip  
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

    change password to db, set name, map, cam, year
    >cp /home/amatyr/etc/config.json.dist /home/amatyr/etc/config.json  
    nano /home/amatyr/etc/config.json

    change server name
    >nano /home/amatyr/nginx.conf

    add nginx path for fast start
    >nano ~/.profile  
    
    add this to the end of file
    >PATH=$PATH:/usr/local/openresty/nginx/sbin  
    export PATH

    apply changes
    >. ~/.profile
    
    now you can start nginx
    > nginx -c /home/amatyr/nginx.conf

6. Everything should work now.

### Live demo

Tor Hveem's personal installation of this project is running at <http://yr.hveem.no>
It has a blog post to go with the setup at <http://hveem.no/raspberry-pi-davis-vue-weather-station-with-custom-frontend>

### License

AmatYr uses a BSD 3-clause license.

    Copyright (c) 2013, Tor Hveem or Project Contributors.
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are
    met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

    * Neither the name of the AmatYr Project, Tor Hveem, nor the names
      of its contributors may be used to endorse or promote products
      derived from this software without specific prior written
      permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
    IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
    THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
    PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
    CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
    EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
    PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
    PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
    LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
    NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.