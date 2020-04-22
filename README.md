My attempt to build a simple imageboard.

Goals:

- Simple to deploy: should be a single executable that uses an sqlite3 db. Put
  it behind a TLS-terminating reverse proxy like nginx or caddy and you're in
  business. Optional s3-like storage is supported.

- Simple to use: UI should be minimal and functional even with JS disabled.
  [textboard](http://textboard.org/) is a huge inspiration.

- Simple (and hopefully fun) to develop: prioritize correctness & simplicity
  over performance in general. Nim + sqlite3 is plenty fast already, and no
  your shitty Mongolian basket weaving forum does not need to be "web scale".

# Dev

```sh
nimble install
sudo pacman -S entr
find src -type f -name '*.nim' | entr -rc nimble run --verbose caophim
xdg-open http://localhost:5000
```

## Design choices

**src/caophim.nim** is the main entrypoint and all state should be managed
there. Other files should only define composable, stateless utils.

This project unapologetically utilizes n+1 queries, since they're [not a
problem with sqlite](https://www.sqlite.org/np1queryprob.html).

# Usage

## Server setup

### Dependencies:

ImageMagick: the version that comes with Ubuntu 18.04 doesn't support webp
(even with libwebp-dev installed) for some reason. Compile from source like
this:

```sh
sudo apt install libwebp-dev
sudo apt build-dep imagemagick

wget 'https://github.com/ImageMagick/ImageMagick/archive/7.0.9-27.tar.gz'
tar -xf 7.0.9-27.tar.gz
cd ImageMagick-7.0.9-27
./configure
make
sudo make install
```

Now run `magick -version`. If it errors out trying to load some library, try
running `ldconfig /usr/local/lib`.

I'm _really really_ tempted to just spin up an Arch server and be done with it.

### S3:

- create your bucket and access id - secret pair
- `cp aws/credentials-example aws/credentials`
- fill key & secret in credentials file
- install aws-cli on server

- `cp config.ini.example config.ini`
- fill s3 configs

I'll need to write code for auto-generating the aws credentials file using
values from config.ini.

## How I'm running it so far

I should write up an ansible playbook at some point...

```sh
adduser --disabled-password caophim
# [gen key, add pubkey to /home/caophim/.ssh/authorized_keys, chmod 600]
su caophim
wget '<caophim-linux64.tar.gz url>'
tar -xf caophim-linux64.tar.gz
# [populate config.ini, aws/credentials]
cd caophim-dist

# Setup systemd service
# as root
curl 'https://git.sr.ht/~nhanb/caophim/blob/master/ops/caophim.service' \
     > /etc/systemd/system/caophim.service
systemctl enable caophim
systemctl start caophim
# site should now be live at port 5000. Let's move on to nginx & TLS

# [add certbot ppa]
apt install nginx certbot
curl 'https://git.sr.ht/~nhanb/caophim/blob/master/ops/caophim.nginx' \
     > /etc/nginx/sites-available/caophim
curl 'https://git.sr.ht/~nhanb/caophim/blob/master/ops/caophim-acme-only.nginx' \
     > /etc/nginx/sites-available/caophim-acme-only
curl 'https://git.sr.ht/~nhanb/caophim/blob/master/ops/letsencrypt.nginx' \
     > /etc/nginx/snippets/letsencrypt.conf
rm -f /etc/nginx/sites-enabled/default
# At this point we don't have tls certs yet so the full caophim nginx
# config won't work, therefore use a minimal config that only serves
# /.well-known/acme-challenge/ to get certs for the first time.
ln -s -f /etc/nginx/sites-available/caophim-acme-only /etc/nginx/sites-enabled/caophim
systemctl restart nginx
mkdir -p /var/www/letsencrypt
# this will create cert files in /etc/letsencrypt/ - see nginx config.
certbot certonly \
  --webroot --webroot-path /var/www/letsencrypt \
  --email caophim@imnhan.com \
  -d caophim.imnhan.com
# Now that we have the cert files in place, serve the full caophim site
ln -s -f /etc/nginx/sites-available/caophim /etc/nginx/sites-enabled/caophim
systemctl restart nginx
