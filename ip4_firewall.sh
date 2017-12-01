#!/bin/bash
# iptables single-host firewall script
#
# -----------------------------------------------------------------------------
# https://gist.github.com/jirutka/3742890
# https://github.com/trick77/ipset-blacklist
# https://making.pusher.com/per-ip-rate-limiting-with-iptables/#fnref:hashlimit-hashtable-mess
# https://www.ossramblings.com/whitelisting-ipaddress-with-iptables-ipset

# Define your command variables
ipt4="/sbin/iptables"
ipset="/sbin/ipset"

clear

echo "                                                            ";
echo " _____     _ _   _    _____                           _     ";
echo "|   __|___| |_|_| |  |   __|_ _ ___ ___ ___ _____ ___| |___ ";
echo "|__   | . | | | . |  |  |  | | | .'|  _| .'|     | . | | -_|";
echo "|_____|___|_|_|___|  |_____|___|__,|___|__,|_|_|_|___|_|___|";
echo "                                                            ";
echo "Script to load our own custom iptables rules"

#
## Update and load ipeset blacklist
## Blacklist is updated daily via a CRON job
#

#
echo
echo "-------------"
echo "BLACKLIST"
echo "-------------"
echo
#

echo "sending blacklist ip's to oblivion"
# Disabled the next line as it is now in a CRON job
#/usr/local/sbin/update-blacklist.sh /etc/ipset-blacklist/ipset-blacklist.conf
$ipset restore < /etc/ipset-blacklist/ip-blacklist.restore

#
echo
echo "-------------"
echo "WHITELIST"
echo "-------------"
echo
#

#
## Load ipset whitelist. To be moved out of here and run like the blacklist.
## Once loaded the ruleset will be loaded later into the AUTH-TRAFFIC chain.
#

echo "allowing whitelist ip's..."
$ipset restore < /etc/ipset-whitelist/ip-whitelist.restore

#
echo
echo "-------------"
echo "NETFILTER"
echo "-------------"
echo
#

echo "flush all rules and delete all chains..."
$ipt4 -F
$ipt4 -X

echo "zero out all counters..."
$ipt4 -Z

echo "Set defaut policy to accept (under review)..."
$ipt4 -P INPUT ACCEPT
$ipt4 -P FORWARD ACCEPT
$ipt4 -P OUTPUT ACCEPT

echo "define our custom chains..."
$ipt4 -N LOG_AND_DROP
$ipt4 -N RATE-LIMIT
$ipt4 -N LOCAL-TRAFFIC
$ipt4 -N AUTH-TRAFFIC

echo "manually set fail2ban chains..."
$ipt4 -N f2b-HTTP
$ipt4 -N f2b-auth
$ipt4 -N f2b-badbots
$ipt4 -N f2b-dovecot-pop3imap
$ipt4 -N f2b-l2tp-psk
$ipt4 -N f2b-noscript
$ipt4 -N f2b-overflows
$ipt4 -N f2b-owncloud
$ipt4 -N f2b-postfix-sasl
$ipt4 -N f2b-roundcube-auth
$ipt4 -N f2b-sshd

#
echo
echo "-------------"
echo "INPUT rules"
echo "-------------"
echo
#

echo "drop via ipset blacklist with syslog tag [BLACKLIST]..."
$ipt4 -A INPUT -m set --match-set blacklist src -j LOG_AND_DROP

echo "allow Local loopback traffic..."
$ipt4 -A INPUT -i lo -j ACCEPT

echo "allow Local AWS IP connections with syslog tag [LOCAL-TRAFFIC]..."
$ipt4 -A INPUT -s 172.31.32.0/24 -p tcp -j LOCAL-TRAFFIC

echo "allow authorized ip's via ipset with syslog tag [AUTH-TRAFFIC]..."
$ipt4 -A INPUT -m set --match-set whitelist src -j AUTH-TRAFFIC

echo "set logging for all other traffic with syslog tag [NETFILTER]..."
$ipt4 -A INPUT -m limit --limit 1/sec -j LOG --log-prefix "[NETFILTER]: "

echo "manually setup Fail2ban rules..."
$ipt4 -A INPUT -p tcp -m tcp --dport 80 -j f2b-HTTP
$ipt4 -A INPUT -p tcp -m multiport --dports 0:65535 -j f2b-l2tp-psk
$ipt4 -A INPUT -p tcp -m multiport --dports 80,443 -j f2b-owncloud
$ipt4 -A INPUT -p tcp -j f2b-sshd
$ipt4 -A INPUT -p tcp -m multiport --dports 80,443 -j f2b-auth
$ipt4 -A INPUT -p tcp -m multiport --dports 110,995,143,993 -j f2b-dovecot-pop3imap
$ipt4 -A INPUT -p tcp -m multiport --dports 25,465,587,220,993,110,995 -j f2b-postfix-sasl
$ipt4 -A INPUT -p tcp -m multiport --dports 80,443 -j f2b-roundcube-auth
$ipt4 -A INPUT -p tcp -m multiport --dports 80,443 -j f2b-overflows
$ipt4 -A INPUT -p tcp -m multiport --dports 80,443 -j f2b-noscript
$ipt4 -A INPUT -p tcp -m multiport --dports 80,443 -j f2b-badbots

echo "allow existing connections and drop invalid. Rate limit NEW connections..."
$ipt4 -A INPUT -m conntrack --ctstate INVALID -j DROP
$ipt4 -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
$ipt4 -A INPUT -m conntrack --ctstate NEW --jump RATE-LIMIT

echo "set VPN access rules..."
$ipt4 -A INPUT -p udp -m multiport --dports 500,4500 -j ACCEPT
$ipt4 -A INPUT -p udp -m udp --dport 1701 -m policy --dir in --pol none -j DROP
$ipt4 -A INPUT -p udp -m udp --dport 1701 -m policy --dir in --pol ipsec -j ACCEPT
$ipt4 -A INPUT -p udp -m udp --dport 1701 -j DROP

echo "allow ping traffic..."
$ipt4 -A INPUT -p icmp -m icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT

#
echo
echo "-------------"
echo "FORWARD rules"
echo "-------------"
echo
#

echo "allow VPN existing connections..."
$ipt4 -A FORWARD -m limit --limit 1/sec -j LOG --log-prefix "[NETFILTER]: "
$ipt4 -A FORWARD -m conntrack --ctstate INVALID -j DROP
$ipt4 -A FORWARD -i eth0 -o ppp+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
$ipt4 -A FORWARD -i ppp+ -o eth0 -j ACCEPT
$ipt4 -A FORWARD -s 192.168.42.0/24 -d 192.168.42.0/24 -i ppp+ -o ppp+ -j ACCEPT
$ipt4 -A FORWARD -d 192.168.43.0/24 -i eth0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
$ipt4 -A FORWARD -s 192.168.43.0/24 -o eth0 -j ACCEPT

echo "drop everything else on the FORWARD chain..."
$ipt4 -A FORWARD -j DROP

#
echo
echo "-------------"
echo "CHAIN ACTIONS"
echo "-------------"
echo
#

# Custom Chain Rule actions

echo "DROP Blacklist ip's..."
$ipt4 -A LOG_AND_DROP -j LOG --log-prefix "[BLACKLIST]: " --log-level 4
$ipt4 -A LOG_AND_DROP -j DROP

echo "Rate Limit allowed traffic..."
$ipt4 -A RATE-LIMIT -m hashlimit --hashlimit-mode srcip --hashlimit-upto 50/sec --hashlimit-burst 20 --hashlimit-name conn_rate_limit -j ACCEPT
$ipt4 -A RATE-LIMIT -m limit --limit 1/sec -j LOG --log-prefix "[IPTables-Rejected]: "
$ipt4 -A RATE-LIMIT -j REJECT --reject-with icmp-port-unreachable

echo "Log local traffic 1 entry per minute..."
$ipt4 -A LOCAL-TRAFFIC -m limit --limit 1/min -j LOG --log-prefix "[LOCAL-TRAFFIC]: " --log-level 1
$ipt4 -A LOCAL-TRAFFIC -j ACCEPT

echo "Log authorized traffic 1 entry per minute..."
$ipt4 -A AUTH-TRAFFIC -m limit --limit 1/min -j LOG --log-prefix "[AUTH-TRAFFIC]: " --log-level 1
$ipt4 -A AUTH-TRAFFIC -j ACCEPT

#
echo
echo "-------------"
echo "RETURN ACTION"
echo "-------------"
echo
#

echo "send all traffic back that passed thru Fail2ban..."
$ipt4 -A f2b-HTTP -j RETURN
$ipt4 -A f2b-auth -j RETURN
$ipt4 -A f2b-badbots -j RETURN
$ipt4 -A f2b-dovecot-pop3imap -j RETURN
$ipt4 -A f2b-l2tp-psk -j RETURN
$ipt4 -A f2b-noscript -j RETURN
$ipt4 -A f2b-overflows -j RETURN
$ipt4 -A f2b-owncloud -j RETURN
$ipt4 -A f2b-postfix-sasl -j RETURN
$ipt4 -A f2b-roundcube-auth -j RETURN
$ipt4 -A f2b-sshd -j RETURN

# Display current rules for testing
echo
echo "-------------"
echo "ACTIVE RULES"
echo "-------------"
echo
iptables -S

#
echo
echo "-------------"
echo "DONE"
echo "-------------"
echo
#

## END
