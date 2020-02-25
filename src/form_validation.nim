import options, strutils
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


proc validateThreadFormData*(request: Request): ThreadFormData =
  let picBlob: string = request.formData["pic"].body
  let picFormat: ImageFormat = getPicFormat(picBlob[0..IMGFORMAT_MAX_BYTES_USED])
  if picFormat == ImageFormat.Unsupported:
    raise newException(UnsupportedImageFormat, "")

  return ThreadFormData(
    pic: Pic(blob: picBlob, format: picFormat),
    content: request.formData["content"].body.strip(),
  )


proc validateReplyFormData*(request: Request): ReplyFormData =
  var picOpt: Option[Pic]

  if request.formData["pic"].body == "":
    picOpt = none(Pic)

  else:
    let picBlob = request.formData["pic"].body
    let picFormat = getPicFormat(picBlob[0..IMGFORMAT_MAX_BYTES_USED])
    if picFormat == ImageFormat.Unsupported:
      raise newException(UnsupportedImageFormat, "")
    picOpt = some(Pic(blob: picBlob, format: picFormat))

  return ReplyFormData(
    pic: picOpt,
    content: request.formData["content"].body.strip(),
  )
