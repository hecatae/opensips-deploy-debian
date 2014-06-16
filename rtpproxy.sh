#!/usr/bin/env bash

cd /usr/src/
git clone git://sippy.git.sourceforge.net/gitroot/sippy/rtpproxy
cd rtpproxy/
./configure
make
make install
ldconfig

echo "local6.*  -/var/log/opensips/rtpproxy.log" >> /etc/rsyslog.conf
/etc/init.d/rsyslog restart

NIC=$(ip r get 8.8.8.8 | head -n1 | awk '{print $7}')

rtpproxy -l $NIC -s udp:127.0.0.1:7890 -F -d DBUG:LOG_LOCAL6 
