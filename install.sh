#!/usr/bin/env bash

# -- Prerequisites 
aptitude -yq=3 install pwgen

# MySQL root password
DBROOTPW=$(pwgen -N1 12 -n)
echo "mysql-server-5.5 mysql-server/root_password password $DBROOTPW" | debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again password $DBROOTPW" | debconf-set-selections

aptitude -yq=2 install gcc bison flex make openssl libmysqlclient15-dev perl libdbi-perl libdbd-mysql-perl libdbd-pg-perl libfrontier-rpc-perl libterm-readline-gnu-perl libberkeleydb-perl mysql-server ssh libxml2 libxml2-dev libxmlrpc-c-dev libpcre3 libpcre3-dev subversion libncurses-dev git ngrep build-essential curl

# OpenSIPS build
cd /usr/src
git clone https://github.com/OpenSIPS/opensips.git -b 1.10 opensips_1_10
cd /usr/src/opensips_1_10/
MODULES="db_mysql dialplan presence presence_dialoginfo presence_mwi presence_xml pua pua_bla pua_dialoginfo pua_mi pua_usrloc pua_xmpp xcap"
sed -i "s,^\(include_modules?\s*=\).*,\1$MODULES," Makefile.conf
sed -i "s,^\(PREFIX\s*=\).*$,\1/," Makefile.conf
make all
make install

# OpenSIPS env
cd /usr/src/opensips_1_10/packaging/debian
cp opensips.default /etc/default/opensips
cp opensips.init /etc/init.d/opensips
chmod +x /etc/init.d/opensips
mkdir /var/run/opensips
mkdir /var/log/opensips
adduser --no-create-home --home /var/run/opensips --shell /usr/sbin/nologin --system --group opensips
update-rc.d opensips defaults 99
chown -R opensips. /var/run/opensips/ /var/log/opensips/ /etc/opensips/
sed -i 's/\(RUN_OPENSIPS\s*=\s*\)no/\1yes/' /etc/default/opensips
sed -i "s|^\(DAEMON\).*$|\1=$(which opensips)|" /etc/init.d/opensips
sed -i 's/^\(S_MEMORY\).*/\1=128/' /etc/default/opensips

CONF=/etc/opensips/opensipsctlrc
DBPASS=$(pwgen -N1 12)
IP=$(ip r get 8.8.8.8 |head -n1|awk '{print $NF}')
sed -i "s|^# \(SIP_DOMAIN=\).*$|\1$IP|" $CONF
sed -i "s|^# \(DBENGINE=MYSQL\)$|\1|" $CONF
sed -i "s|^# \(DBHOST=localhost\)$|\1|" $CONF
sed -i "s|^# \(DBNAME=opensips\)$|\1|" $CONF
sed -i "s|^# \(DBRWUSER=opensips\)$|\1|" $CONF
sed -i "s|^# \(DBRWPW=\).*$|\1$DBPASS|" $CONF
sed -i 's|^# \(DBROOTUSER="root"\)$|\1|' $CONF
mysql -uroot -p$DBROOTPW -e "grant all on opensips.* to opensips@localhost identified by '$DBPASS'"
mysql -uroot -p$DBROOTPW -e "flush privileges"
export PW=$DBROOTPW
yes | opensipsdbctl create opensips

# Log rotate and syslog
cat <<x23 > /etc/logrotate.d/opensips
rotate 5
  daily
  compress
  missingok
  create 0644 opensips opensips
}
x23
echo "local5.*  -/var/log/opensips/opensips.log" >> /etc/rsyslog.conf
/etc/init.d/rsyslog restart

# mysql 
cat <<x123 > ~/.my.cnf
[mysql]
user=root
password=$DBROOTPW
host=localhost
x123

cat <<x23ssh > ~/.ssh/config
Host github.com
  HostName github.com
  Port 22
  StrictHostKeyChecking no
  
x23ssh

# setup vim
\curl -s https://raw.githubusercontent.com/staskobzar/myvimbasic/master/install.sh | bash


