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


# Read config right from the beginning
let conf*: CaophimConf = readConfig()
