import db_sqlite, strutils
import database

# Re-process content nodes in db

when isMainModule:
  let db = getDbConn()
  let rows = db.getAllRows(sql"select id, content from post order by id;")

  db.exec(sql"begin transaction;")
  for r in rows:
    let id = r[0]
    let content = r[1]
    db.processContent(content, parseInt(id))
  db.exec(sql"commit;")
