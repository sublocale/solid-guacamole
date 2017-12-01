# solid-guacamole
## Designed for use on a Amazon AWS instance

You don’t generally need to worry about using a host-level firewall such as
iptables when running Amazon EC2, because Amazon allows you to run instances
inside a "security group", which is effectively a firewall policy that you use
to specify which connections from the outside world should be allowed to reach
the instance. That said, it is a good idea to direct, control, and log what does
make it thru.

This script will setup iptables to do the following;

- load blacklists and create a [BLACKLIST] tag for log review
- load whitelists and create a [WHITELIST] tag for log review
  - limit logging for whitelisted IP's to stop log from filling up syslog
  - skip fail2ban review of white listed IP's
- integrate with fail2ban to DROP blacklisted IP's prior to jail review
  - log all other traffic with [NETFILTER] tag for log review with sane logging
  frequency
  - rate limit any connections that survive fail2ban review
- allow VPN access resulting from https://github.com/hwdsl2/setup-ipsec-vpn

If you recognize any code and there is no attribution please feel free to add it in. I have tried to acknowledge all code but in many cases I was on a google hunt to solve issues and neglected to note sources.

Please take note, I am not a programmer and mostly bandaid others good work together to get the desired result. If something goes wrong, you have been warned!

## Requirements

### Platforms

- Ubuntu/Debian
- RHEL/CentOS and derivatives
- Amazon Linux

### Tools
- ipset - `apt-get install ipset` or `yum install ipset`
- ipset-blacklist - https://github.com/trick77/ipset-blacklist
- ipset-whitelist - https://github.com/sublocale/ipset-whitelist
- fail2ban - https://www.fail2ban.org/wiki/index.php/Main_Page

### Notes:
+ Currently configured for a POSTFIX/DOVECOT mail and LAMP server.
+ I have tried to keep this POSIX compliant based on shellcheck complaints.

### Contributing

+ Fork the project
+ Send a pull request

### Licence

Solid-Guacamole is released under the [MIT license](LICENSE.txt). 
