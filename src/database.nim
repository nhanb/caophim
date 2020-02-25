import db_sqlite, sequtils, sugar, options, strutils
import imgformat

const DB_FILE_NAME = "db.sqlite3"

type
  Board* = object
    slug*: string
    name*: string

  Thread* = object
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
    threadId*: int64


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

  #[
  A Post can either be a Thread or Reply.
  It's a Reply iff it has a thread_id.

  This is baby's first Single Table Inheritance implementation so bear with me:
    - CheckConstraints at least provide some guarantees. (TODO)
    - The thread/reply views help avoid mistakes when querying one of the two.

  In return we can cleanly implement universal "link to post" regardless of if
  the post is a thread or reply.
  ]#

  db.exec(sql"""
  CREATE TABLE IF NOT EXISTS post (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pic_format text,
    content text NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    thread_id int, -- reply-only field
    board_slug text, -- thread-only field
    FOREIGN KEY (thread_id) REFERENCES post(id) ON DELETE CASCADE,
    FOREIGN KEY (board_slug) REFERENCES board(slug) ON DELETE CASCADE
  );
  """)

  db.exec(sql"""
  CREATE VIEW IF NOT EXISTS thread AS
    SELECT id, pic_format, content, created_at, board_slug
    FROM post WHERE thread_id IS NULL;
  """)

  db.exec(sql"""
  CREATE VIEW IF NOT EXISTS reply AS
    SELECT id, pic_format, content, created_at, thread_id
    FROM post WHERE thread_id IS NOT NULL;
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


proc createThread*(
  db: DbConn,
  boardSlug: string,
  pic: string, # but is actually binary data
  picFormat: string,
  content: string
): int64 =
  return db.insertID(sql"""
  INSERT INTO post(board_slug, pic_format, content)
  VALUES (?, ?, ?);
  """, boardSlug, picFormat, content)


proc deleteThread*(db: DbConn, threadId: int64) =
  db.exec(sql"DELETE FROM post WHERE thread_id IS NULL and id = ?;", threadId)


proc getBoard*(db: DbConn, slug: string): Option[Board] =
  let name = db.getValue(sql"SELECT name FROM board WHERE slug = ?;", slug)
  if name == "":
    return none(Board)
  else:
    return some(Board(slug: slug, name: name))


proc getThreads*(db: DbConn, board: Board): seq[Thread] =
  let rows = db.getAllRows(sql"""
  SELECT
    id, pic_format, content, created_at,
    (SELECT count(*) from reply where reply.thread_id = thread.id) as num_replies
  FROM thread
  WHERE board_slug = ?
  ORDER BY id DESC
  LIMIT 50;
  """, board.slug)
  return rows.map(proc(r: seq[string]) : Thread =
    Thread(
      id: r[0],
      picFormat: parseEnum[ImageFormat](r[1]),
      content: r[2],
      createdAt: r[3],
      boardSlug: board.slug,
      numReplies: some(r[4].parseInt)
    )
  )


proc getThread*(db: DbConn, board: Board, threadId: int64): Option[Thread] =
  let r = db.getRow(sql"""
  SELECT id, pic_format, content, created_at
  FROM thread
  WHERE board_slug = ?
  AND id = ?;
  """, board.slug, threadId)
  if r[0] == "":
    return none(Thread)
  else:
    return some(Thread(
      id: r[0],
      picFormat: parseEnum[ImageFormat](r[1]),
      content: r[2],
      createdAt: r[3],
      boardSlug: board.slug
    ))


proc threadExists*(db: DbConn, threadId: int64): bool =
  return db.getValue(sql"SELECT 1 FROM thread WHERE id = ? LIMIT 1;", threadId) == "1"


proc getBoardSlugFromThreadId*(db: DbConn, threadId: int64): string =
  return db.getValue(sql"""
  SELECT board.slug
  FROM board
    INNER JOIN thread ON thread.board_slug = board.slug
  WHERE thread.id = ?;
  """, threadId)


proc createReply*(
  db: DbConn,
  threadId: int64,
  picFormat: string,
  content: string
): int64 =
  return db.insertID(sql"""
  INSERT INTO post(thread_id, pic_format, content) VALUES (?, ?, ?);
  """, threadId, picFormat, content)


proc getReplies*(db: DbConn, thread: Thread): seq[Reply] =
  let rows = db.getAllRows(sql"""
  SELECT id, pic_format, content, created_at
  FROM reply
  WHERE thread_id = ?
  ORDER BY id;
  """, thread.id)
  return rows.map(r => Reply(
    id: r[0],
    picFormat:
      if r[1] == "": none(ImageFormat)
      else: some(parseEnum[ImageFormat](r[1])),
    content: r[2],
    createdAt: r[3],
    threadId: thread.id.parseInt()
  ))
