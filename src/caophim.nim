import options, strformat, strutils
import jester
import karax / [karaxdsl, vdom]
import database, frontend, imgformat
import storage / [filesystem]

type
  TopicInput = object
    pic: string
    picFormat: ImageFormat
    content: string
    board_slug: string


createPicsDir()


let db = getDbConn()
db.createDb()
db.seedBoards()


routes:

  get "/":
    let boards: seq[Board] = db.getBoards()
    let body = buildHtml(tdiv(class="home-container")):
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
    let topics: seq[Topic] = db.getTopics(board)

    let body = buildHtml(tdiv):

      h1(): text fmt"/{slug}/ - {board.name}"

      if len(topics) == 0:
        text "No topics yet."
      else:
        for topic in topics:
          renderTopic(topic)

      form(
        class="create-topic-form",
        action=fmt"/{slug}/",
        `method`="POST",
        enctype="multipart/form-data"
      ):
        label(`for`="create-topic-content"): text "Content:"
        textarea(name="content", id="create-topic-content", rows="7", required="true"): text ""
        label(): text "Pic:"
        input(`type`="file", name="pic", id="create-topic-pic", required="true")
        button(`type`="submit"): text "Create topic"

    resp wrapHtml(body, fmt"/{slug}/")


  post "/@board_slug/":
    let slug = @"board_slug"
    let boardOption = db.getBoard(slug)
    if boardOption.isNone():
      resp Http404, "Board not found."
      return

    var ti: TopicInput
    try:
      # TODO: move this into a "deserializer" proc
      let pic: string = request.formData["pic"].body
      let picFormat: ImageFormat = getPicFormat(pic[0..IMGFORMAT_MAX_BYTES_USED])
      if picFormat == ImageFormat.Unsupported:
        resp Http400, "Unsupported image format."
        return
      ti = TopicInput(
        pic: pic,
        picFormat: picFormat,
        content: request.formData["content"].body.strip(),
        boardSlug: slug
      )
    except:
      resp Http400, "Invalid form input."
      return

    let topicId = await db.createTopic(
      ti.boardSlug,
      ti.pic,
      ti.picFormat,
      ti.content
    )
    try:
      await savePic(ti.pic, fmt"{topicId}.{ti.picFormat}")
    except:
      db.deleteTopic(topicId)
      resp Http500, "Failed to create topic."
      return

    redirect fmt"/{slug}/{topicId}/"


  get "/@board_slug/@topic_id/":
    let slug = @"board_slug"
    let boardOption = db.getBoard(slug)
    if boardOption.isNone():
      resp Http404, "Board not found."
      return

    var topicId: int
    try:
      topicId = (@"topic_id").parseInt()
    except ValueError:
      resp Http404, "Topic not found"
      return

    let topicOption = db.getTopic(boardOption.get(), topicId)
    if topicOption.isNone():
      resp Http404, "Topic not found."
      return

    let topic = topicOption.get()
    let body = buildHtml(tdiv):
      renderTopic(topic)
      form(
        class="create-reply-form",
        action=fmt"/{slug}/{topic.id}/",
        `method`="POST",
        enctype="multipart/form-data"
      ):
        label(`for`="create-reply-content"): text "Reply:"
        textarea(name="content", id="create-reply-content", rows="7", required="true"): text ""
        label(): text "Pic:"
        input(`type`="file", name="pic", id="create-reply-pic")
        button(`type`="submit"): text "Reply"

    let content = topic.content
    var titleText = content[0..min(80, content.len - 1)]
    if "\c\n" in titleText:
      titleText = titleText[0..titleText.find("\c\n")-1]
    elif titleText.len < content.len:
      titleText.add("...")

    resp wrapHtml(body, titleText)
