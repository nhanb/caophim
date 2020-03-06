import options, strformat, strutils
import jester
import karax / [karaxdsl, vdom]
import database, frontend, form_validation, cpconf
import storage / [s3]

createPicsDirs()

let db = getDbConn()
db.createDb()
db.seedBoards()

conf = readConfig()

routes:

  get "/":
    let boards: seq[Board] = db.getBoards()
    let body = buildHtml(tdiv):
      h1():
        a(href="/"): text "caophim"
        text " /"
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
        text " / "
        a(href=fmt"/{slug}/"): text fmt"{slug}"
        text " / "
        text fmt" - {board.name}"

      if len(threads) == 0:
        h2(): text "No threads yet."
      else:
        h2():
          text fmt"Showing "
          strong(): text fmt"{threads.len}"
          text if threads.len == 1: " thread" else: " threads"
          text fmt" in /{slug}/"
        for thread in threads:
          db.renderThread(thread)

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
        tdiv(class="pic-input-wrapper"):
          input(`type`="file", name="pic", id="create-thread-pic", required="true")
          img(class="pic-preview", src="")
        button(`type`="submit"): text "Create thread"

    resp wrapHtml(body, fmt"/{slug}/")


  post "/@board_slug/":
    let slug = @"board_slug"
    let boardOption = db.getBoard(slug)
    if boardOption.isNone():
      resp Http404, "Board not found."
      return

    var tfd: ThreadFormData
    try:
      # TODO: don't rely on the catch-all exception handler to catch stuff like
      # index out of bounds error - it's bad form and isn't future-proof anyway:
      # https://nim-lang.org/araq/gotobased_exceptions.html
      tfd = validateThreadFormData(request)
    except UnsupportedImageFormat:
      resp Http400, "Unsupported image format."
      return
    except:
      resp Http400, "Invalid form input."
      return

    let threadId = db.createThread(
      slug,
      tfd.pic.blob,
      $tfd.pic.format,
      tfd.content
    )
    try:
      await savePic(tfd.pic.blob, $threadId, $tfd.pic.format)
    except:
      db.deleteThread(threadId)
      resp Http500, "Failed to upload pic."
      echo "ERRRRR: " & getCurrentExceptionMsg()
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
    if "\n" in titleText:
      titleText = titleText[0..titleText.find("\n")-1]
    elif titleText.len < content.len:
      titleText.add("...")


    let body = buildHtml(tdiv):
      h1():
        a(href="/"): text "caophim"
        text " / "
        a(href=fmt"/{slug}/"): text fmt"{slug}"
        text " / "
        a(href=fmt"/{slug}/{thread.id}/"): text fmt"{thread.id}"
        text fmt" / - {titleText}"
      db.renderThread(thread)
      db.renderReplies(replies, thread=thread)
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
        tdiv(class="pic-input-wrapper"):
          input(`type`="file", name="pic", id="create-reply-pic")
          img(class="pic-preview", src="")
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

    var rfd: ReplyFormData
    try:
      # TODO: don't rely on the catch-all exception handler to catch stuff like
      # index out of bounds error - it's bad form and isn't future-proof anyway:
      # https://nim-lang.org/araq/gotobased_exceptions.html
      rfd = validateReplyFormData(request)
    except:
      resp Http400, "Invalid form input."
      return

    let replyId: int64 = db.createReply(
      threadId,
      if rfd.pic.isNone(): "" else: $rfd.pic.get().format,
      rfd.content
    )

    if rfd.pic.isSome():
      let pic = rfd.pic.get()
      try:
        await savePic(pic.blob, $replyId, $pic.format)
      except:
        db.deleteReply(replyId)
        resp Http500, "Failed to upload pic."
        echo "ERRRRR: " & getCurrentExceptionMsg()
        return

    let boardSlug = db.getBoardSlugFromThreadId(threadId)
    redirect fmt"/{boardSlug}/{threadId}/#{replyId}"
