import asyncfile, os, asyncdispatch, strformat

const PICS_DIR = "public" / "pics"

# TODO: probably should move all thread/reply pics path related logic into this
# module.


proc createPicsDirs*() =
  discard existsOrCreateDir(PICS_DIR)


proc savePic*(blob: string, filename: string, format: string) {.async} =
  var file = openAsync(PICS_DIR / fmt"{filename}.{format}", fmReadWrite)
  await file.write(blob)
  file.close()


proc getPostPicUrl*(fullFileName: string): string =
  return fmt"/pics/{fullFileName}"
