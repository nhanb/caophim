import htmlgen, jester
import database


let db = getDbConn()
db.createDb()
db.seedBoards()

routes:
  get "/":
    let boards: seq[Board] = db.getBoards()
    resp code($boards)
