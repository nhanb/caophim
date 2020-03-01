import asyncfile, asyncdispatch, strformat, os
import ../cpconf

const PICS_DIR = "public" / "pics"


proc createPicsDirs*() =
  discard existsOrCreateDir(PICS_DIR)


proc savePic*(blob: string, filename: string, format: string) {.async} =
  let localFilePath = PICS_DIR / fmt"{filename}.{format}"

  # Save file to disk locally
  var file = openAsync(localFilePath, fmReadWrite)
  await file.write(blob)
  file.close()

  # TODO the following code is EXTREMELY NAIVE: it does a _blocking_ call to
  # shell out to aws-cli for uploading. Remember to go back to this and actually
  # use the REST API properly with an asynchttpclient.
  let uploadCmd = (
    "export AWS_SHARED_CREDENTIALS_FILE=aws/credentials && " &
    fmt"aws s3 --endpoint-url='https://s3.{conf.s3.region}.{conf.s3.host}' " &
    fmt"cp '{localFilePath}' 's3://{conf.s3.bucket}/' --content-type image/{format}"
  )
  echo uploadCmd
  let errC = execShellCmd(uploadCmd)
  echo "Upload status: " & $errC

  # Delete after successful upload
  if errC == 0:
    removeFile(localFilePath)


proc getPostPicUrl*(fullFileName: string): string =
  return fmt"https://{conf.s3.bucket}/{fullFileName}"
