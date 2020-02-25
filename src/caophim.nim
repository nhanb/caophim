import options, strformat, strutils
import jester
import karax / [karaxdsl, vdom]
import database, frontend, imgformat
import storage / [filesystem]

type
  ThreadInput = object
    pic: string
    picFormat: ImageFormat
    content: string
    boardSlug: string

  ReplyInput = object
    pic: Option[string]
    picFormat: Option[ImageFormat]
    content: string
    threadId: int64


createPicsDirs()


let db = getDbConn()
db.createDb()
db.seedBoards()


routes:

  get "/":
    let boards: seq[Board] = db.getBoards()
    let body = buildHtml(tdiv):
      h1():
        a(href="/"): text "caophim"
        text "/"
      h2(): text "Pick your poison:"
      tdiv(class="boards"):
        for board in boards:
          tdiv():
            a(href=fmt"/{board.slug}/"): text fmt"/{board.slug}/"
            text fmt" - {board.name}"
    resp wrapHtml(body)


  get "/@board_slug/":
    let slug = @"board_slug"
    let boardOption = db.getBoard(slug)
    if boardOption.isNone():
      resp Http404, "Board not found."
      return

    let board: Board = boardOption.get()
    let threads: seq[Thread] = db.getThreads(board)

    let body = buildHtml(tdiv):

      h1():
        a(href="/"): text "caophim"
        text fmt"/{slug}/ - {board.name}"

      if len(threads) == 0:
        h2(): text "No threads yet."
      else:
        h2():
          text fmt"Showing "
          strong(): text fmt"{threads.len}"
          text if threads.len == 1: " thread" else: " threads"
          text fmt" in /{slug}/"
        for thread in threads:
          renderThread(thread)

      form(
        class="create-thread-form",
        action=fmt"/{slug}/",
        `method`="POST",
        enctype="multipart/form-data"
      ):
        label(`for`="create-thread-content"): text "New thread:"
        textarea(
          name="content",
          id="create-thread-content",
          rows="7",
          required="true",
          placeholder="Create new thread here"
        ): text ""
        label(): text "Pic:"
        input(`type`="file", name="pic", id="create-thread-pic", required="true")
        button(`type`="submit"): text "Create thread"

    resp wrapHtml(body, fmt"/{slug}/")


  post "/@board_slug/":
    let slug = @"board_slug"
    let boardOption = db.getBoard(slug)
    if boardOption.isNone():
      resp Http404, "Board not found."
      return

    var ti: ThreadInput
    try:
      # TODO: move this into a "deserializer" proc
      # Also, don't rely on the catch-all exception handler to catch stuff like
      # index out of bounds error:
      # https://nim-lang.org/araq/gotobased_exceptions.html
      let pic: string = request.formData["pic"].body
      let picFormat: ImageFormat = getPicFormat(pic[0..IMGFORMAT_MAX_BYTES_USED])
      if picFormat == ImageFormat.Unsupported:
        resp Http400, "Unsupported image format."
        return
      ti = ThreadInput(
        pic: pic,
        picFormat: picFormat,
        content: request.formData["content"].body.strip(),
        boardSlug: slug
      )
    except:
      resp Http400, "Invalid form input."
      return

    let threadId = db.createThread(
      ti.boardSlug,
      ti.pic,
      $ti.picFormat,
      ti.content
    )
    try:
      await savePic(ti.pic, fmt"{threadId}.{ti.picFormat}")
    except:
      db.deleteThread(threadId)
      resp Http500, "Failed to create thread."
      return

    redirect fmt"/{slug}/{threadId}/"


  get "/@board_slug/@thread_id/":
    let slug = @"board_slug"
    let boardOption = db.getBoard(slug)
    if boardOption.isNone():
      resp Http404, "Board not found."
      return

    var threadId: int64
    try:
      threadId = (@"thread_id").parseInt()
    except ValueError:
      resp Http404, "Thread not found"
      return

    let threadOption = db.getThread(boardOption.get(), threadId)
    if threadOption.isNone():
      resp Http404, "Thread not found."
      return

    var thread = threadOption.get()
    let replies = db.getReplies(thread)
    thread.numReplies = some(len(replies))

    let content = thread.content
    var titleText = content[0..min(80, content.len - 1)]
    if "\c\n" in titleText:
      titleText = titleText[0..titleText.find("\c\n")-1]
    elif titleText.len < content.len:
      titleText.add("...")


    let body = buildHtml(tdiv):
      h1():
        a(href="/"): text "caophim"
        text "/"
        a(href=fmt"/{slug}/"): text fmt"{slug}"
        text fmt"/{thread.id}/ - {titleText}"
      renderThread(thread)
      renderReplies(replies, thread=thread)
      form(
        class="create-reply-form",
        action=fmt"/reply/{thread.id}/",
        `method`="POST",
        enctype="multipart/form-data"
      ):
        label(`for`="create-reply-content"): text "Reply:"
        textarea(
          name="content",
          id="create-reply-content",
          rows="7",
          required="true",
          placeholder="Reply here"
        ): text ""
        label(): text "Pic (optional):"
        input(`type`="file", name="pic", id="create-reply-pic")
        button(`type`="submit"): text "Reply"

    resp wrapHtml(body, titleText)


  post "/reply/@thread_id/":
    let threadIdStr = @"thread_id"
    var threadId: int64
    try:
      threadId = threadIdStr.parseInt()
    except ValueError:
      resp Http400, "Invalid thread ID."
      return

    if not db.threadExists(threadId):
      resp Http400, "Thread not found."
      return

    var ri: ReplyInput
    try:
      # TODO: move this into a "deserializer" proc
      # Also, don't rely on the catch-all exception handler to catch stuff like
      # index out of bounds error:
      # https://nim-lang.org/araq/gotobased_exceptions.html
      var picOpt: Option[string]
      var picFormatOpt: Option[ImageFormat]
      if request.formData["pic"].body == "":
        picOpt = none(string)
        picFormatOpt = none(ImageFormat)
      else:
        let pic = request.formData["pic"].body
        let picFormat = getPicFormat(pic[0..IMGFORMAT_MAX_BYTES_USED])
        if picFormat == ImageFormat.Unsupported:
          resp Http400, "Unsupported image format."
          return
        picOpt = some(pic)
        picFormatOpt = some(picFormat)
      ri = ReplyInput(
        pic: picOpt,
        picFormat: picFormatOpt,
        content: request.formData["content"].body.strip(),
        threadId: threadId
      )
    except:
      resp Http400, "Invalid form input."
      return

    let replyId: int64 = db.createReply(
      ri.threadId,
      if ri.picFormat.isNone(): "" else: $ri.picFormat.get(),
      ri.content
    )

    if ri.pic.isSome():
      try:
        await savePic(ri.pic.get(), fmt"{replyId}.{ri.picFormat.get()}")
      except:
        db.deleteThread(threadId)
        resp Http500, "Failed to create thread."
        return

    let boardSlug = db.getBoardSlugFromThreadId(threadId)
    redirect fmt"/{boardSlug}/{threadId}/#{replyId}"
