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
openssl req -new -newkey rsa -nodes -x509 -keyout squid.key  -out squid.crt -subj "/O=squid/CN=Squid CA"
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
squid -k parse

squid -d 10
```

## Using intermediate certificates

You can use an intermediate CA on the proxy for SSL-Bump. In case if the intermediate certificate being compromised, you can simply revoke the intermediate with root and sign new intermediate without disturb your clients.

Start by downloading [openssl.cnf](openssl.cnf) and creating the certificates with the commands below.

```bash
openssl req -new -newkey rsa -nodes -x509 -keyout root.key -out root.crt -subj "/O=squid/CN=Squid Global Root CA"
openssl req -new -newkey rsa -nodes -keyout squid.key -out squid.csr -subj "/O=squid/CN=Squid Intermediate CA"
touch index.txt
echo 1000 > serial
```

The next command must be executed by itself because it will require user input to confirm the operation.

```bash
openssl ca -config openssl.cnf -extensions v3_intermediate_ca -notext -md sha256 -in squid.csr -out squid.crt
```

Now let's create the multiple pem files required.

```bash
cat squid.key squid.crt | tee squid.pem
cat squid.crt root.crt | tee chain.pem
```

Now we will configure Squid to send the intermediate and root certificates so we do not need to install the intermediate to clients. We will add the `cafile` attribute as below.

```squid
https_port 3130 intercept ssl-bump generate-host-certificates=on cert=/etc/squid/ssl/squid.pem cafile=/etc/squid/ssl/chain.pem
```

## Clients

Any client trying to access the Internet going thru our proxy, should not accept the self-signed certificate used by our proxy. We can add it as a trusted CA.

```sh
mkdir /usr/share/ca-certificates/extra
```

Copy `/etc/squid/ssl/squid.crt`, or `/etc/squid/ssl/root.crt` if using intermediate certificate, to the directory create above. It is a simple text file, copy and past will do the trick. Next we need to update our certificats.

```sh
dpkg-reconfigure ca-certificates
```

## Debugging tips

`tcpdump` can help you debug proper routing.  You should be able to see HTTP requests coming from the client host.

```sh
tcpsump dst port 443
```

`openssl s_client` can help you better understand the certificates chain received by the client.

```sh
openssl s_client -connect www.datadoghq.com:443 -quiet
```

## Useful resources

[OpenSSL](https://www.openssl.org/)

[SSL-Bump using an intermediate CA](https://wiki.squid-cache.org/ConfigExamples/Intercept/SslBumpWithIntermediateCA)

[OpenSSL Certificate Authority](https://jamielinux.com/docs/openssl-certificate-authority/index.html)
