import db_sqlite, sequtils, sugar, options, strutils
import imgformat

const DB_FILE_NAME = "db.sqlite3"

type
  Board* = object
    slug*: string
    name*: string

  Topic* = object
    id*: string
    picFormat*: ImageFormat
    content*: string
    createdAt*: string
    boardSlug*: string
    numReplies*: Option[int]

  Reply* = object
    id*: string
    picFormat*: Option[ImageFormat]
    content*: string
    createdAt*: string
    topicId*: int64


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
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pic_format text NOT NULL,
    content text NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    board_slug int NOT NULL,
    FOREIGN KEY (board_slug) REFERENCES board(slug) ON DELETE CASCADE
  );
  """)

  db.exec(sql"""
  CREATE TABLE IF NOT EXISTS reply (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pic_format text,
    content text,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    topic_id int NOT NULL,
    FOREIGN KEY (topic_id) REFERENCES topic(id) ON DELETE CASCADE
  );
  """)


proc seedBoards*(db: DbConn) =
  db.exec(sql"""
  INSERT INTO board(slug, name)
  VALUES
    ('dev', 'devlet support group'),
    ('rand', 'anything goes')
  ON CONFLICT(slug) DO UPDATE SET name=excluded.name;
  """)


proc getBoards*(db: DbConn): seq[Board] =
  let results = db.getAllRows(sql"SELECT slug, name FROM board ORDER BY slug;")
  let boards = results.map(row => Board(slug: row[0], name: row[1]))
  return boards


proc createTopic*(
  db: DbConn,
  boardSlug: string,
  pic: string, # but is actually binary data
  picFormat: string,
  content: string
): int64 =
  return db.insertID(sql"""
  INSERT INTO topic(board_slug, pic_format, content)
  VALUES (?, ?, ?);
  """, boardSlug, picFormat, content)


proc deleteTopic*(db: DbConn, topicId: int64) =
  db.exec(sql"DELETE FROM topic WHERE id = ?;", topicId)


proc getBoard*(db: DbConn, slug: string): Option[Board] =
  let name = db.getValue(sql"SELECT name FROM board WHERE slug = ?;", slug)
  if name == "":
    return none(Board)
  else:
    return some(Board(slug: slug, name: name))


proc getTopics*(db: DbConn, board: Board): seq[Topic] =
  let rows = db.getAllRows(sql"""
  SELECT
    id, pic_format, content, created_at,
    (SELECT count(*) from reply where reply.topic_id = topic.id) as num_replies
  FROM topic
  WHERE board_slug = ?
  ORDER BY id DESC
  LIMIT 50;
  """, board.slug)
  return rows.map(proc(r: seq[string]) : Topic =
    Topic(
      id: r[0],
      picFormat: parseEnum[ImageFormat](r[1]),
      content: r[2],
      createdAt: r[3],
      boardSlug: board.slug,
      numReplies: some(r[4].parseInt)
    )
  )


proc getTopic*(db: DbConn, board: Board, topicId: int64): Option[Topic] =
  let r = db.getRow(sql"""
  SELECT id, pic_format, content, created_at
  FROM topic
  WHERE board_slug = ?
  AND id = ?;
  """, board.slug, topicId)
  if r[0] == "":
    return none(Topic)
  else:
    return some(Topic(
      id: r[0],
      picFormat: parseEnum[ImageFormat](r[1]),
      content: r[2],
      createdAt: r[3],
      boardSlug: board.slug
    ))


proc topicExists*(db: DbConn, topicId: int64): bool =
  return db.getValue(sql"SELECT 1 FROM topic WHERE id = ? LIMIT 1;", topicId) == "1"


proc getBoardSlugFromTopicId*(db: DbConn, topicId: int64): string =
  return db.getValue(sql"""
  SELECT board.slug
  FROM board
    INNER JOIN topic ON topic.board_slug = board.slug
  WHERE topic.id = ?;
  """, topicId)


proc createReply*(
  db: DbConn,
  topicId: int64,
  picFormat: string,
  content: string
): int64 =
  return db.insertID(sql"""
  INSERT INTO reply(topic_id, pic_format, content) VALUES (?, ?, ?);
  """, topicId, picFormat, content)


proc getReplies*(db: DbConn, topic: Topic): seq[Reply] =
  let rows = db.getAllRows(sql"""
  SELECT id, pic_format, content, created_at
  FROM reply
  WHERE topic_id = ?
  ORDER BY id;
  """, topic.id)
  return rows.map(r => Reply(
    id: r[0],
    picFormat:
      if r[1] == "": none(ImageFormat)
      else: some(parseEnum[ImageFormat](r[1])),
    content: r[2],
    createdAt: r[3],
    topicId: topic.id.parseInt()
  ))
