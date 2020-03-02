import asyncfile, os, asyncdispatch, strformat
import ../imgprocessing

const PICS_DIR = "public" / "pics"


proc createPicsDirs*() =
  discard existsOrCreateDir(PICS_DIR)


proc savePic*(blob: string, filename: string, format: string) {.async} =
  var file = openAsync(PICS_DIR / fmt"{filename}.{format}", fmReadWrite)
  await file.write(blob)
  file.close()

  discard createThumbnail(PICS_DIR, filename, format)


proc getPostPicUrl*(postId: string, picFormat: string): string =
  return fmt"/pics/{postId}.{picFormat}"

proc getPostThumbUrl*(postId: string, picFormat: string): string =
  return fmt"/pics/{postId}.thumb.{picFormat}"
