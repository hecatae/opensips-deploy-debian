#!/usr/bin/env bash

aptitude -y install apache2 php5 php5-cli php5-gd php5-mysql php5-xmlrpc php-pear
pear install MDB2 MDB2#mysql log

cd /var/www/
svn checkout svn://svn.code.sf.net/p/opensips-cp/code/trunk opensips-cp
chown -R www-data. opensips-cp/

echo Alias /cp \"/var/www/opensips-cp/web\" >> /etc/apache2/apache2.conf
/etc/init.d/apache2 restart

mysql opensips < /var/www/opensips-cp/config/tools/admin/add_admin/ocp_admin_privileges.mysql
mysql opensips -e "INSERT INTO ocp_admin_privileges (username,password,ha1,available_tools,permissions) \
  values ('admin','admin',md5('admin:admin'),'all','all');"

sed -i 's/admin_passwd_mode=1/admin_passwd_mode=0/' /var/www/opensips-cp/config/globals.php
mysql opensips < /var/www/opensips-cp/config/tools/system/cdrviewer/cdrs.mysql
mysql opensips < /var/www/opensips-cp/config/tools/system/cdrviewer/opensips_cdrs.mysql

DBPW=$(grep pass ~/.my.cnf | cut -d= -f2)
sed -i "s#\(PASS=\"\).*#\1$DBPW\"#" /var/www/opensips-cp/cron_job/generate-cdrs_mysql.sh
mysql opensips < /var/www/opensips-cp/config/tools/system/smonitor/tables.mysql

cat <<x23CRON > /etc/cron.d/opensips-cp
*/3 * * * * root /var/www/opensips-cp/cron_job/generate-cdrs_mysql.sh 
* * * * * root php /var/www/opensips-cp/cron_job/get_opensips_stats.php > /dev/null
x23CRON

/etc/init.d/cron restart

#Assign the proper rights to opensips_fifo 
#vi /etc/opensips/opensips.cfg
#modparam("mi_fifo", "fifo_mode", 0666)

/etc/init.d/opensips restart
/etc/init.d/apache2 restart

# configure OpenSIPS-CP
sed -i "s/\(config->db_pass\s*=\)\(.*\)$/\1\"$DBPW\";/" /var/www/opensips-cp/config/db.inc.php

sed -i 's|xmlrpc:127.0.0.1:8888|/tmp/opensips_fifo|' /var/www/opensips-cp/config/boxes.global.inc.php
sed -i "s|xmlrpc:127.0.0.1:8888|/tmp/opensips_fifo|" /var/www/opensips-cp/config/tools/system/dialog/local.inc.php
sed -i "s|/tmp/opensips_proxy_fifo|/tmp/opensips_fifo|" /var/www/opensips-cp/config/tools/system/dispatcher/local.inc.php



