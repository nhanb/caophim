import db_sqlite, sequtils, sugar, options, strutils, re, json, strformat, uri
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
    parsedContent*: seq[ContentNode]
    createdAt*: string
    boardSlug*: string
    numReplies*: Option[int]

  Reply* = object
    id*: string
    picFormat*: Option[ImageFormat]
    content*: string
    parsedContent*: seq[ContentNode]
    createdAt*: string
    threadId*: int64

  PostType* = enum
    ThreadType = "thread"
    ReplyType = "reply"
  ContentNodeKind* = enum
    P,
    Br,
    Text,
    Quote,
    Link,
    Hyperlink,
    YoutubeLink
  ContentNode* = object
    case kind*: ContentNodeKind
    of P: pChildren*: seq[ContentNode]
    of Br: nil
    of Text: textStr*: string
    of Quote: quoteStr*: string
    of Link:
      linkText*: string
      linkHref*: string
      linkType*: PostType
      linkPostId*: int64
      linkThreadId*: int64
    of Hyperlink: url*: string
    of YoutubeLink: ytid*: string

proc getDbConn*(): DbConn =
  let db = open(DB_FILE_NAME, "", "", "")
  db.exec(sql"PRAGMA foreign_keys = 1;")  # always enforce foreign key checks
  return db


proc createDb*(db: DbConn)=
  echo "sqlite version: " & db.getValue(sql"select sqlite_version();")
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
    parsed_content text,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    thread_id int, -- reply-only field
    board_slug text, -- thread-only field
    FOREIGN KEY (thread_id) REFERENCES post(id) ON DELETE CASCADE,
    FOREIGN KEY (board_slug) REFERENCES board(slug) ON DELETE CASCADE
  );
  """)

  db.exec(sql"""
  CREATE VIEW IF NOT EXISTS thread AS
    SELECT id, pic_format, content, parsed_content, created_at, board_slug
    FROM post WHERE thread_id IS NULL;
  """)

  db.exec(sql"""
  CREATE VIEW IF NOT EXISTS reply AS
    SELECT id, pic_format, content, parsed_content, created_at, thread_id
    FROM post WHERE thread_id IS NOT NULL;
  """)

  db.exec(sql"""
  CREATE TABLE IF NOT EXISTS link (
    post_id INTEGER NOT NULL,
    linked_post_id INTEGER NOT NULL,
    FOREIGN KEY (post_id) REFERENCES post(id) ON DELETE CASCADE,
    FOREIGN KEY (linked_post_id) REFERENCES post(id) ON DELETE CASCADE,
    UNIQUE (post_id, linked_post_id)
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


proc processContent*(db: DbConn, content: string, postId: int64) =
  # Convert windows-style newlines into unix style:
  # (per html spec, textarea form input always submits win-style newlines)
  var c = content.replace(re"\r\n", "\n")

  # Truncate 3-or-more consecutive newlines
  c = c.replace(re"\n\n(\n)+", "\n\n")

  var nodes: seq[ContentNode]

  # Poor man's parser into the simplest node graph we can get away with, just
  # enough structure for rendering the html later.
  #
  # Also populate the `link` db table, so we can query "this post is quoted by
  # which other posts"
  for paragraph in c.split("\n\n"):
    var p = ContentNode(kind: P)

    for line in paragraph.split("\n"):
      if line.match(re(r"^>>\d+$")):
        var linkedId: int64 = 0
        try:
          linkedId = parseInt(line[2..^1])
        except ValueError:
          discard # so linkedId stays 0

        # If id is not valid int or is linking to itself: treat line as text
        if linkedId == 0 or linkedId == postId:
          p.pChildren.add(ContentNode(kind: Text, textStr: line))

        else:
          # Query to make sure linked ID actually exists:
          let r = db.getRow(sql"""
          SELECT id, thread_id, board_slug
          FROM post WHERE id = ? AND id < ?;
          """, linkedId, postId)

          if r[0] == "":
            # not found: treat as normal text
            p.pChildren.add(ContentNode(kind: Text, textStr: line))

          else:
            let linkedPostThreadId = r[1]
            var linkHref: string
            var linkThreadId: int64
            var linkType: PostType
            if linkedPostThreadId == "":
              linkType = ThreadType
              linkHref = fmt"/{r[2]}/{linkedId}/#{linkedId}"
              linkThreadId = linkedId
            else:
              linkType = ReplyType
              linkThreadId = linkedPostThreadId.parseInt()
              let boardSlug = db.getValue(sql"""
              SELECT board_slug FROM thread WHERE id = ?;
              """, linkedPostThreadId)
              linkHref = fmt"/{boardSlug}/{linkedPostThreadId}/#{linkedId}"

            # found: add Link node
            p.pChildren.add(ContentNode(
              kind: Link,
              linkText: line,
              linkHref: linkHref,
              linkType: linkType,
              linkPostId: linkedId,
              linkThreadId: linkThreadId,
            ))
            # also create `link` db record:
            db.exec(sql"""
            INSERT INTO link (post_id, linked_post_id)
            VALUES (?, ?)
            ON CONFLICT DO NOTHING;
            """, postId, linkedId)

      elif line.match(re(r"^>.+$")):
        p.pChildren.add(ContentNode(kind: Quote, quoteStr: line))

      elif line.match(re(r"^https?://")):
        let uri = parseUri(line)

        var youtubeId: string = ""
        if uri.hostname in ["youtube.com", "www.youtube.com"] and uri.query != "":
          for part in uri.query.split('&'):
            let pair = part.split('=')
            if pair[0] == "v":
              youtubeId = pair[1]
              break
        elif uri.hostname == "youtu.be" and uri.path.len > 1 and not ('/' in uri.path[1..^1]):
          youtubeId = uri.path[1..^1]

        if youtubeId != "":
          p.pChildren.add(ContentNode(kind: YoutubeLink, ytid: youtubeId))
        else:
          p.pChildren.add(ContentNode(kind: Hyperlink, url: line))

      else:
        p.pChildren.add(ContentNode(kind: Text, textStr: line))

      p.pChildren.add(ContentNode(kind: Br))

    nodes.add(p)

  # Save the whole thing into db
  db.exec(sql"""
  UPDATE post
  SET parsed_content = ?
  WHERE id = ?
  """, $(%*nodes), postId)


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
  db.exec(sql"BEGIN TRANSACTION;")

  let threadId = db.insertID(sql"""
  INSERT INTO post(board_slug, pic_format, content)
  VALUES (?, ?, ?);
  """, boardSlug, picFormat, content)

  db.processContent(content, threadId)

  db.exec(sql"COMMIT;")
  return threadId


proc deleteThread*(db: DbConn, threadId: int64) =
  db.exec(sql"DELETE FROM post WHERE thread_id IS NULL and id = ?;", threadId)


proc deleteReply*(db: DbConn, replyId: int64) =
  db.exec(sql"DELETE FROM post WHERE thread_id IS NOT NULL and id = ?;", replyId)


proc getBoard*(db: DbConn, slug: string): Option[Board] =
  let name = db.getValue(sql"SELECT name FROM board WHERE slug = ?;", slug)
  if name == "":
    return none(Board)
  else:
    return some(Board(slug: slug, name: name))


proc getThreads*(db: DbConn, board: Board): seq[Thread] =
  let rows = db.getAllRows(sql"""
  SELECT
    id, pic_format, content, parsed_content, created_at,
    (SELECT count(*) from reply where reply.thread_id = thread.id) as num_replies,
    COALESCE (
      (SELECT max(id) from reply where reply.thread_id = thread.id),
      id
    ) as last_reply_or_thread_id
  FROM thread
  WHERE board_slug = ?
  ORDER BY last_reply_or_thread_id DESC
  LIMIT 50;
  """, board.slug)
  return rows.map(proc(r: seq[string]) : Thread =
    Thread(
      id: r[0],
      picFormat: parseEnum[ImageFormat](r[1]),
      content: r[2],
      parsedContent: r[3].parseJson().to(seq[ContentNode]),
      createdAt: r[4],
      boardSlug: board.slug,
      numReplies: some(r[5].parseInt)
    )
  )


proc getThread*(db: DbConn, board: Board, threadId: int64): Option[Thread] =
  let r = db.getRow(sql"""
  SELECT id, pic_format, content, parsed_content, created_at
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
      parsedContent: r[3].parseJson().to(seq[ContentNode]),
      createdAt: r[4],
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
  db.exec(sql"BEGIN TRANSACTION;")

  let replyId = db.insertID(sql"""
  INSERT INTO post(thread_id, pic_format, content) VALUES (?, ?, ?);
  """, threadId, picFormat, content)

  db.processContent(content, replyId)

  db.exec(sql"COMMIT;")
  return replyId


proc getReplies*(db: DbConn, thread: Thread): seq[Reply] =
  let rows = db.getAllRows(sql"""
  SELECT id, pic_format, content, parsed_content, created_at
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
    parsedContent: r[3].parseJson().to(seq[ContentNode]),
    createdAt: r[4],
    threadId: thread.id.parseInt()
  ))


proc getLinksToPost(db: DbConn, linkedPostId: int64, linkedThreadId: int64): seq[int64] =
  let rows = db.getAllRows(sql"""
  SELECT reply.id
  FROM link INNER JOIN reply ON reply.id = link.post_id
  WHERE link.linked_post_id = ?
    AND reply.thread_id = ?;
  """, linkedPostId, linkedThreadId)
  return rows.map(proc (r: seq[string]): int64 = r[0].parseInt)

proc getLinks*(db: DbConn, reply: Reply): seq[int64] =
  return db.getLinksToPost(reply.id.parseInt, reply.thread_id)

proc getLinks*(db: DbConn, thread: Thread): seq[int64] =
  let threadId = thread.id.parseInt
  return db.getLinksToPost(threadId, threadId)
