#!/bin/sh
#Block ads, malware, etc.

# Redirect endpoint
ENDPOINT_IP4="0.0.0.0"
ENDPOINT_IP6="::"
IPV6="Y"

#Delete the old block.hosts to make room for the updates
rm -f /etc/block.hosts

echo 'Downloading hosts lists...'
#Download and process the files needed to make the lists (enable/add more, if you want)
wget -qO- http://www.mvps.org/winhelp2002/hosts.txt| awk -v r="$ENDPOINT_IP4" '{sub(/^0.0.0.0/, r)} $0 ~ "^"r' > /tmp/block.build.list
wget -qO- "http://adaway.org/hosts.txt"|awk -v r="$ENDPOINT_IP4" '{sub(/^127.0.0.1/, r)} $0 ~ "^"r' >> /tmp/block.build.list
wget -qO- http://www.malwaredomainlist.com/hostslist/hosts.txt|awk -v r="$ENDPOINT_IP4" '{sub(/^127.0.0.1/, r)} $0 ~ "^"r' >> /tmp/block.build.list
wget -qO- "http://hosts-file.net/.\ad_servers.txt"|awk -v r="$ENDPOINT_IP4" '{sub(/^127.0.0.1/, r)} $0 ~ "^"r' >> /tmp/block.build.list

#Add black list, if non-empty
if [ -s "/etc/black.list" ]
then
    echo 'Adding blacklist...'
    awk -v r="$ENDPOINT_IP4" '/^[^#]/ { print r,$1 }' /etc/black.list >> /tmp/block.build.list
fi

#Sort the download/black lists
awk '{sub(/\r$/,"");print $1,$2}' /tmp/block.build.list|sort -u > /tmp/block.build.before

#Filter (if applicable)
if [ -s "/etc/white.list" ]
then
    #Filter the blacklist, supressing whitelist matches
    #  This is relatively slow =-(
    echo 'Filtering white list...'
    egrep -v "^[[:space:]]*$" /etc/white.list | awk '/^[^#]/ {sub(/\r$/,"");print $1}' | grep -vf - /tmp/block.build.before > /etc/block.hosts
else
    cat /tmp/block.build.before > /etc/block.hosts
fi

if [ "$IPV6" = "Y" ]
then
    safe_pattern=$(printf '%s\n' "$ENDPOINT_IP4" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
    safe_addition=$(printf '%s\n' "$ENDPOINT_IP6" | sed 's/[\&/]/\\&/g')
    echo 'Adding ipv6 support...'
    sed -i -re "s/^(${safe_pattern}) (.*)$/\1 \2\n${safe_addition} \2/g" /etc/block.hosts
fi

service dnsmasq restart

exit 0
