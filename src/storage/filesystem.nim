import asyncfile, os, asyncdispatch

const PICS_DIR = "public" / "pics"

# TODO: probably should move all thread/reply pics path related logic into this
# module.


proc createPicsDirs*() =
  discard existsOrCreateDir(PICS_DIR)


proc savePic*(blob: string, filename: string) {.async} =
  var file = openAsync(PICS_DIR / filename, fmReadWrite)
  await file.write(blob)
  file.close()
