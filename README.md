**NOTE: this is on indefinite hiatus**, mostly thanks to my disillusionment
with the current state of nim. However, it's still live at
https://caophim.imnhan.com if you're curious.

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

Targets Debian 11 (bullseye).

### Dependencies:

```sh
sudo apt install imagemagick awscli
```

### S3:

- create your bucket and access id - secret pair
- `cp aws/credentials-example aws/credentials`
- fill key & secret in credentials file
- `cp config.ini.example config.ini`
- fill s3 configs

I'll need to write code for auto-generating the aws credentials file using
values from config.ini.

## How I'm running it so far

~~I should write up an ansible playbook at some point...~~
I have a private [pyinfra](https://pyinfra.com/) setup that works alright,
though I don't have any plans to open source it, since that box is also hosting
some other stuff.

Anyway, here are the manual steps:

```sh
adduser --disabled-password caophim
# [gen key, add pubkey to /home/caophim/.ssh/authorized_keys, chmod 600]
su caophim
wget 'https://github.com/nhanb/caophim/releases/download/v0.1.1/caophim-linux64.tar.gz'
tar -xf caophim-linux64.tar.gz
cd caophim-dist
# [populate config.ini, aws/credentials]

# Setup systemd service
# as root
curl 'https://git.sr.ht/~nhanb/caophim/blob/master/ops/caophim.service' \
     > /etc/systemd/system/caophim.service
systemctl enable caophim
systemctl start caophim
# site should now be live at port 5000.

# Now you need some HTTP reverse proxy that handles TLS. I recommend Caddy:
# [install caddy v2]
# [either cp or symlink from ./ops/caophim.caddy to /etc/caddy/sites-enabled/caophim]
systemctl restart caddy
