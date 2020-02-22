import db_sqlite, sequtils, sugar, options, strformat, strutils, asyncdispatch
import imgformat

const DB_FILE_NAME = "db.sqlite3"

type
  Board* = object
    slug*: string
    name*: string

type
  Topic* = object
    id*: string
    picFormat*: ImageFormat
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
  CREATE TABLE IF NOT EXISTS topic (
    pic_format text NOT NULL,
    content text NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    board_slug int NOT NULL,
    FOREIGN KEY (board_slug) REFERENCES board(slug) ON DELETE CASCADE
  );
  """)

  db.exec(sql"""
  CREATE TABLE IF NOT EXISTS reply (
    pic_format text,
    content text,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    topic_id int NOT NULL,
    FOREIGN KEY (topic_id) REFERENCES topic(rowid) ON DELETE CASCADE
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


proc createTopic*(
  db: DbConn,
  savePic: proc(blob: string, filename: string): Future[void],
  boardSlug: string,
  pic: string, # but is actually binary data
  picFormat: ImageFormat,
  content: string
): Future[Option[int]] {.async.} =
  # Wrap the whole thing inside a transaction so if savePic() fails the topic
  # won't be committed to db:
  db.exec(sql"BEGIN TRANSACTION;")
  try:
    # First insert into db with so we can get a topic ID:
    db.exec(sql"""
    INSERT INTO topic(board_slug, pic_format, content)
    VALUES (?, ?, ?);
    """, boardSlug, $picFormat, content)
    let topicId: string = db.getRow(sql"SELECT last_insert_rowid();")[0]
    echo fmt"Inserted topic id {topicId}"

    # Now save to disk, using topic ID as filename
    await savePic(pic, fmt"{topicId}.{$picFormat}")

    db.exec(sql"COMMIT;")
    return some(topicId.parseInt())

  except:
    db.exec(sql"ROLLBACK;")
    return none(int)

proc getBoard*(db: DbConn, slug: string): Option[Board] =
  let row = db.getRow(sql"SELECT name FROM board WHERE slug = ?;", slug)
  let name = row[0]
  if name == "":
    return none(Board)
  else:
    return some(Board(slug: slug, name: name))


proc getTopics*(db: DbConn, board: Board): seq[Topic] =
  let rows = db.getAllRows(sql"""
  SELECT rowid, pic_format, content, created_at
  FROM topic
  WHERE board_slug = ?
  ORDER BY rowid DESC;
  """, board.slug)
  return rows.map(proc(r: seq[string]) : Topic =
    Topic(
      id: r[0],
      picFormat: parseEnum[ImageFormat](r[1]),
      content: r[2],
      created_at: r[3],
      board_slug: board.slug
    )
  )


proc getTopic*(db: DbConn, board: Board, topicId: int): Option[Topic] =
  let r = db.getRow(sql"""
  SELECT rowid, pic_format, content, created_at
  FROM topic
  WHERE board_slug = ?
  AND rowid = ?;
  """, board.slug, topicId)
  if r[0] == "":
    return none(Topic)
  else:
    return some(Topic(
      id: r[0],
      picFormat: parseEnum[ImageFormat](r[1]),
      content: r[2],
      created_at: r[3],
      board_slug: board.slug
    ))
