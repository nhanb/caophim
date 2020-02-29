My attempt to build a simple imageboard.

Goals:

- Simple to deploy: should be a single executable that uses an sqlite3 db. Put
  it behind a TLS-terminating reverse proxy like nginx or caddy and you're in
  business. Optional s3-like storage support is planned.

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

S3:

- create your bucket and access id - secret pair
- `cp aws/credentials-example aws/credentials`
- fill key & secret in credentials file
- install aws-cli on server

- `cp config.ini.example config.ini`
- fill s3 configs

I'll need to write code for auto-generating the aws credentials file using
values from config.ini.
