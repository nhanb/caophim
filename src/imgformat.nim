type
  ImageFormat* = enum
    GIF = "gif",
    JPEG = "jpeg",
    PNG = "png",
    WEBP = "webp",
    Unsupported = ""

const IMGFORMAT_MAX_BYTES_USED* = 11


proc getPicFormat*(pic: string) : ImageFormat =
  if pic[0..7] == "\137PNG\13\10\26\10": return PNG
  if pic[0..3] == "RIFF" and pic[8..11] == "WEBP": return WEBP
  if pic[0..5] == "GIF87a" or pic[0..5] == "GIF89a": return GIF
  if pic[6..9] == "JFIF" or pic[6..9] == "Exif": return JPEG
  return Unsupported
