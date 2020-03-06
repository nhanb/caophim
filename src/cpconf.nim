import parsecfg

type
  S3Conf* = object
    bucket*: string
    region*: string
    host*: string

  CaophimConf* = object
    s3*: S3Conf

const CONF_FILE_PATH = "config.ini"


proc readConfig*(): CaophimConf =
  let dict = loadConfig(CONF_FILE_PATH)

  let s3 = S3Conf(
    bucket: dict.getSectionValue("s3", "bucket"),
    region: dict.getSectionValue("s3", "region"),
    host: dict.getSectionValue("s3", "host"),
  )

  return CaophimConf(
    s3: s3,
  )


# To avoid gc safety warnings, conf needs to be a threadvar so it can be used in
# an async context. Now that it is a threadvar, it must be initialized in the
# main thread which is caophim.nim.
#
# All of the above is not even strictly necessary right now because I'm not
# running jester in multithreaded mode anyway, but having a false positive
# compiler warning is annoying and may distract me from real issues further down
# the line.
var conf* {.threadvar.}: CaophimConf
