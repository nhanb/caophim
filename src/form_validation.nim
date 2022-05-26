import options, strutils, re
import jester
import imgformat


type
  Pic* = object
    blob*: string
    format*: ImageFormat

  ThreadFormData* = object
    pic*: Pic
    content*: string

  ReplyFormData* = object
    pic*: Option[Pic]
    content*: string

  UnsupportedImageFormat* = object of Exception
  IsSpam* = object of Exception


proc cleanUp(content: string): string =
  # 1. Strip
  # 2. Convert windows-style newlines into unix style
  #    (per html spec, textarea form input always submits win-style newlines)
  # 3. Truncate 3-or-more consecutive newlines
  return content.strip().replace(re"\r\n", "\n").replace(re"\n\n(\n)+", "\n\n")


proc validateThreadFormData*(request: Request): ThreadFormData =
  let picBlob: string = request.formData["pic"].body
  let picFormat: ImageFormat = getPicFormat(picBlob[0..IMGFORMAT_MAX_BYTES_USED])
  if picFormat == ImageFormat.Unsupported:
    raise newException(UnsupportedImageFormat, "")

  return ThreadFormData(
    pic: Pic(blob: picBlob, format: picFormat),
    content: cleanUp(request.formData["content"].body),
  )


proc validateReplyFormData*(request: Request): ReplyFormData =
  var picOpt: Option[Pic]
  var content: string

  if request.formData["pic"].body == "":
    picOpt = none(Pic)

  else:
    let picBlob = request.formData["pic"].body
    let picFormat = getPicFormat(picBlob[0..IMGFORMAT_MAX_BYTES_USED])
    if picFormat == ImageFormat.Unsupported:
      raise newException(UnsupportedImageFormat, "")
    picOpt = some(Pic(blob: picBlob, format: picFormat))

  content = cleanUp(request.formData["content"].body)
  if content.contains("newfasttadalafil"):
    raise newException(IsSpam, "")

  return ReplyFormData(
    pic: picOpt,
    content: content,
  )
