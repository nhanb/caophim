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
