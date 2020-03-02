import asyncfile, asyncdispatch, strformat, os
import ../cpconf, ../imgprocessing

const PICS_DIR = "public" / "pics"


proc createPicsDirs*() =
  discard existsOrCreateDir(PICS_DIR)


proc uploadPicAndThumb(filename: string, format: string): int =
  # TODO the following code is EXTREMELY NAIVE: it does a _blocking_ call to
  # shell out to aws-cli for uploading. Remember to go back to this and actually
  # use the REST API properly with an asynchttpclient.
  let uploadCmd = fmt"""
    export AWS_SHARED_CREDENTIALS_FILE=aws/credentials && \
    aws s3 --endpoint-url='https://s3.{conf.s3.region}.{conf.s3.host}' \
    cp '{PICS_DIR}/' 's3://{conf.s3.bucket}/' \
    --recursive --exclude="*" --include="{filename}.*{format}" \
    --content-type image/{format}"""
  echo uploadCmd
  let errC = execShellCmd(uploadCmd)
  echo "Upload status: " & $errC

  return errC

proc savePic*(blob: string, filename: string, format: string) {.async} =
  let localFilePath = PICS_DIR / fmt"{filename}.{format}"

  # Save file to disk locally
  var file = openAsync(localFilePath, fmReadWrite)
  await file.write(blob)
  file.close()

  let thumbPath: string = createThumbnail(PICS_DIR, filename, format)

  let errC = uploadPicAndThumb(filename, format)
  if errC == 0:
    removeFile(localFilePath)
    removeFile(thumbPath)


proc getPostPicUrl*(postId: string, picFormat: string): string =
  return fmt"https://{conf.s3.bucket}/{postId}.{picFormat}"


proc getPostThumbUrl*(postId: string, picFormat: string): string =
  return fmt"https://{conf.s3.bucket}/{postId}.thumb.{picFormat}"
