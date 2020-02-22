import options
import jester
import karax / [karaxdsl, vdom]
import database, frontend


let db = getDbConn()
db.createDb()
db.seedBoards()


routes:
  get "/":
    let boards: seq[Board] = db.getBoards()
    let body = buildHtml(tdiv):
      for board in boards:
        pre(text $board)
    resp wrapHtml(body)

  get "/@board_slug":
    let slug = @"board_slug"
    let boardOption = db.getBoard(slug)

    if boardOption.isNone():
      resp Http404, "Board not found."

    else:
      let board: Board = boardOption.get()
      let threads: seq[Thread] = db.getThreads(board)
      let body = buildHtml(tdiv):
        if len(threads) == 0:
          text "No threads yet."
        else:
          for thread in threads:
            pre: text $thread
      resp wrapHtml(body)
