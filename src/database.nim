import db_sqlite, sequtils, sugar, options

const DB_FILE_NAME = "db.sqlite3"

type
  Board* = object
    slug*: string
    name*: string

type
  Thread* = object
    id*: string
    pic_url*: string
    content*: string
    created_at*: string
    board_slug*: string


proc getDbConn*(): DbConn =
  let db = open(DB_FILE_NAME, "", "", "")
  db.exec(sql"PRAGMA foreign_keys = 1;")  # always enforce foreign key checks
  return db


proc createDb*(db: DbConn)=
  db.exec(sql"""
  CREATE TABLE IF NOT EXISTS board (
    slug text UNIQUE NOT NULL,
    name text NOT NULL
  );
  """)

  db.exec(sql"""
  CREATE TABLE IF NOT EXISTS thread (
    id int NOT NULL PRIMARY KEY,
    pic_url text NOT NULL,
    content text NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    board_slug int NOT NULL,
    FOREIGN KEY (board_slug) REFERENCES board(slug) ON DELETE CASCADE
  );
  """)

  db.exec(sql"""
  CREATE TABLE IF NOT EXISTS reply (
    id int NOT NULL PRIMARY KEY,
    pic_url text,
    content text,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    thread_id int NOT NULL,
    FOREIGN KEY (thread_id) REFERENCES thread(id) ON DELETE CASCADE
  );
  """)


proc seedBoards*(db: DbConn) =
  db.exec(sql"""
  INSERT INTO board(slug, name)
  VALUES
    ('dev', 'devlet banters'),
    ('rand', 'anything goes')
  ON CONFLICT(slug) DO UPDATE SET name=excluded.name;
  """)


proc getBoards*(db: DbConn): seq[Board] =
  let results = db.getAllRows(sql"SELECT * FROM board ORDER BY slug;")
  let boards = results.map(row => Board(slug: row[0], name: row[1]))
  return boards


proc createThread*(db: DbConn,
                   board_slug: string,
                   pic_url: string,
                   content: string) =
  db.exec(sql"""
  INSERT INTO thread(board_slug, pic_url, content)
  VALUES (?, ?, ?);
  """, board_slug, pic_url, content)


proc getBoard*(db: DbConn, slug: string): Option[Board] =
  let row = db.getRow(sql"SELECT name FROM board WHERE slug = ?;", slug)
  let name = row[0]
  if name == "":
    return none(Board)
  else:
    return some(Board(slug: slug, name: name))


proc getThreads*(db: DbConn, board: Board): seq[Thread] =
  let rows = db.getAllRows(sql"""
  SELECT id, pic_url, content, created_at FROM thread WHERE board_slug = ?;
  """, board.slug)
  return rows.map(proc(r: seq[string]) : Thread =
    Thread(
      id: r[0],
      pic_url: r[1],
      content: r[2],
      created_at: r[3],
      board_slug: board.slug
    )
  )
