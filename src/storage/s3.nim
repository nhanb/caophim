import asyncfile, asyncdispatch, strformat, os

const PICS_DIR = "public" / "pics"

# TODO: probably should move all thread/reply pics path related logic into this
# module.

#TODO make configurable
const BUCKET = "p.caophim.net"
const ENDPOINT_URL = "https://s3.us-west-1.wasabisys.com"


proc createPicsDirs*() =
  discard existsOrCreateDir(PICS_DIR)


proc savePic*(blob: string, filename: string) {.async} =
  let localFilePath = PICS_DIR / filename

  # Save file to disk locally
  var file = openAsync(localFilePath, fmReadWrite)
  await file.write(blob)
  file.close()

  # TODO the following code is EXTREMELY NAIVE: it does a _blocking_ call to
  # shell out to aws-cli for uploading. Remember to go back to this and actually
  # use the REST API properly with an asynchttpclient.
  let uploadCmd = (
    "export AWS_SHARED_CREDENTIALS_FILE=aws/credentials && " &
    fmt"aws s3 --endpoint-url='{ENDPOINT_URL}' " &
    fmt"cp '{localFilePath}' 's3://{BUCKET}/'"
  )
  echo uploadCmd
  let errC = execShellCmd(uploadCmd)
  echo "Upload status: " & $errC

  # Delete after successful upload
  if errC == 0:
    removeFile(localFilePath)


proc getPostPicUrl*(filename: string): string =
  return fmt"https://{BUCKET}/{filename}"
