import asyncfile, os, asyncdispatch

const PICS_DIR = "public" / "pics"
const REPLY_PICS_DIR = PICS_DIR / "r"

# TODO:
# probably should move all topic/reply pics path related logic into this module.


proc createPicsDirs*() =
  discard existsOrCreateDir(PICS_DIR)
  discard existsOrCreateDir(REPLY_PICS_DIR)


proc savePic*(blob: string, filename: string) {.async} =
  var file = openAsync(PICS_DIR / filename, fmReadWrite)
  await file.write(blob)
  file.close()

proc saveReplyPic*(blob: string, filename: string) {.async} =
  var file = openAsync(REPLY_PICS_DIR / filename, fmReadWrite)
  await file.write(blob)
  file.close()
