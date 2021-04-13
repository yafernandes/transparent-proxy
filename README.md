# Transparent Proxy

This lab creates a environment with a [Transparent Proxy](https://en.wikipedia.org/wiki/Proxy_server#Transparent_proxy) setup based on [Squid](http://www.squid-cache.org/) on AWS.

We will be installing Squid from source so we can enable the required flags, `--with-openssl` and `--enable-ssl-crtd`.

```sh
apt update
apt-get install -y build-essential libssl-dev

VERSION=4.14
wget http://www.squid-cache.org/Versions/v4/squid-$VERSION.tar.gz
tar xfv squid-$VERSION.tar.gz
cd squid-$VERSION

./configure --prefix=/usr \
--localstatedir=/var \
--libexecdir=/usr/lib/squid \
--datadir=/usr/share/squid \
--sysconfdir=/etc/squid \
--with-default-user=proxy \
--with-logdir=/var/log/squid \
--with-pidfile=/var/run/squid.pid \
--with-openssl \
--enable-ssl-crtd

make
make install
```

Create the ssl certificates used by Squid.

```sh
mkdir -p /etc/squid/ssl && cd /etc/squid/ssl
openssl req -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -extensions v3_ca -keyout squid.key  -out squid.crt -subj "/C=XX/ST=XX/L=squid/O=squid/CN=squid"
cat squid.key squid.crt | tee squid.pem
```

Create a very simple, permissive, squid configuration.

```sh
cat | tee /etc/squid/squid.conf <<EOF
visible_hostname squid

#Handling HTTP requests
http_port 3128
http_port 3129 intercept
http_access allow all

#Handling HTTPS requests
https_port 3130 intercept ssl-bump generate-host-certificates=on cert=/etc/squid/ssl/squid.pem 
ssl_bump bump all

EOF

squid -k parse
```

We need to reroute incoming HTTP requests to Squid.

```sh
iptables -t nat -A PREROUTING -p tcp --dport  80 -j REDIRECT --to-port 3129
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 3130
```

Before starting Squid, we will fix some permissions and initialize the ssl db directory, and create any missing swap directories.

```sh
chown -R proxy:proxy /var/log/squid

/usr/lib/squid/security_file_certgen -c -s /var/cache/squid/ssl_db -M 4MB
squid -z
```

I tipically like to start Squid with the command below to I can easily check for any issues.

```sh
squid -d 10
```

## Clients

Any client trying to access the Internet going thru our proxy, should not accept the self-signed certificate used by our proxy. We can add it as a trusted CA.

```sh
mkdir /usr/share/ca-certificates/extra
```

Copy `/etc/squid/ssl/squid.crt` to the cirectory create above. It is a simple text file, copy and past will do the trick. Next we need to update our certificats.

```sh
dpkg-reconfigure ca-certificates
```

## Debugging tips

`tcpdump` can help you debug proper routing.  You should be able to see HTTP requests coming from the client host.

```sh
tcpsump dst port 443
```

`openssl` can help you better understand the certificates used.

```sh
openssl s_client www.datadoghq.com:443
```
