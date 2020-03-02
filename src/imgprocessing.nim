import os, strformat


proc createThumbnail*(picsDir: string, filename: string, format: string): string =
  let inFile = picsDir / filename & "." & format
  let outFile = picsDir / filename & ".thumb." & format
  let thumbCmd = fmt"convert {inFile} -coalesce -resize 200x200 {outFile}"
  echo thumbCmd
  let errC = execShellCmd(thumbCmd)
  echo "Create thumbnail status: " & $errC
  return outFile
