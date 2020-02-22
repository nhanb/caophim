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
          let picUrl = fmt"/pics/{topic.id}.{topic.pic_format}"
          tdiv(class="topic"):
            a(href=picUrl):
              img(class="topic-pic", src=picUrl)
            tdiv(class="topic-content"):
              # TODO: consider storing pre-processed paragraphs instead
              # of splitting on every view here
              for paragraph in topic.content.split("\c\n\c\n"):
                p():
                  for line in paragraph.split("\c\n"):
                    text line
                    br()

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
        content: request.formData["content"].body,
        boardSlug: slug
      )
    except:
      resp Http400, "Invalid form input."
      return

    let topicIdOption = await db.createTopic(
      savePic,
      ti.boardSlug,
      ti.pic,
      ti.picFormat,
      ti.content
    )
    if topicIdOption.isNone():
      resp Http500, "Failed to create topic."
    else:
      redirect fmt"/{slug}/{topicIdOption.get()}/"


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

    resp wrapHtml(text $topicOption.get())
