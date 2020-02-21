My attempt to build a simple imageboard.

Goals:
  + Simple to deploy: should be a single executable that uses an sqlite3 db.
  + Simple to use: UI should be minimal and functional even with JS disabled.
    [textboard](http://textboard.org/) is a huge influence.

# Dev

```sh
sudo pacman -S entr
ls src/* | entr -rc nimble run --verbose caophim
xdg-open http://localhost:5000
```
