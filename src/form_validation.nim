import options, strutils
import jester
import imgformat


type
  ThreadFormData* = object
    pic*: string
    picFormat*: ImageFormat
    content*: string

  ReplyFormData* = object
    pic*: Option[string]
    picFormat*: Option[ImageFormat]
    content*: string

  UnsupportedImageFormat* = object of Exception


proc validateThreadFormData*(request: Request): ThreadFormData =
  let pic: string = request.formData["pic"].body
  let picFormat: ImageFormat = getPicFormat(pic[0..IMGFORMAT_MAX_BYTES_USED])
  if picFormat == ImageFormat.Unsupported:
    raise newException(UnsupportedImageFormat, "")

  return ThreadFormData(
    pic: pic,
    picFormat: picFormat,
    content: request.formData["content"].body.strip(),
  )


proc validateReplyFormData*(request: Request): ReplyFormData =
  var picOpt: Option[string]
  var picFormatOpt: Option[ImageFormat]
  if request.formData["pic"].body == "":
    picOpt = none(string)
    picFormatOpt = none(ImageFormat)
  else:
    let pic = request.formData["pic"].body
    let picFormat = getPicFormat(pic[0..IMGFORMAT_MAX_BYTES_USED])
    if picFormat == ImageFormat.Unsupported:
      raise newException(UnsupportedImageFormat, "")
    picOpt = some(pic)
    picFormatOpt = some(picFormat)
  return ReplyFormData(
    pic: picOpt,
    picFormat: picFormatOpt,
    content: request.formData["content"].body.strip(),
  )
