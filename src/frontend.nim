import strformat, strutils, options, db_sqlite
import karax / [karaxdsl, vdom]
import database
import storage / [s3]


proc wrapHtml*(element: VNode, pageTitle: string = ""): string =
  # Basically a base HTML template
  let titleText = (if pageTitle == "": "" else: pageTitle & " - ") & "cào phím beta"

  let html = buildHtml(html):
    head:
      title: text titleText
      meta(name="viewport", content="width=device-width, initial-scale=1.0")
      link(rel="stylesheet", href="/css/reset.css")
      link(rel="stylesheet", href="/css/style.css")
    body:
      element

  return "<!DOCTYPE html>\n" & $html


proc renderContentNode(node: ContentNode, thread: Thread): VNode =
  case node.kind
  of P:
    return buildHtml(p):
      for child in node.pChildren:
        renderContentNode(child, thread)
  of Br: return verbatim("<br />")
  of Text: return text node.textStr
  of Quote:
    return buildHtml(span(class="greentext")): text node.quoteStr
  of Link:
    let class =
      if $node.linkThreadId != thread.id: "cross-link"
      elif $node.linkPostId == thread.id: "op-link"
      else: ""
    return buildHtml(a(href=node.linkHref, class=class)): text node.linkText


proc renderContent(
  class: string,
  content: seq[ContentNode],
  thread: Thread
): VNode =

  return buildHtml(tdiv(class=class)):
    for node in content:
      renderContentNode(node, thread=thread)


proc renderLinks(boardSlug: string, threadId: string, linkingIds: seq[int64]): VNode =
  return buildHtml(span(class="links")):
    for id in linkingIds:
      a(href=fmt"/{boardSlug}/{threadId}/#{id}"): text fmt">>{id}"


proc renderThread*(db: DbConn, thread: Thread): VNode =
  let picUrl = getPostPicUrl(fmt"{thread.id}.{thread.pic_format}")
  let links = db.getLinks(thread)
  return buildHtml(tdiv(class="thread")):
    a(href=picUrl, class="thread-pic-anchor"):
      img(class="thread-pic", src=picUrl)
    tdiv(class="thread-header"):
      a(href=fmt"/{thread.boardSlug}/{thread.id}/", id=thread.id, class="permalink"):
        text "/" & thread.id & "/"
      time(datetime=thread.createdAt & "+00:00"): text thread.createdAt & " UTC"
      if thread.numReplies.isSome():
        let num = thread.numReplies.get()
        text ", "
        span(class=if num == 0: "" else: "bold"):
          text fmt"{num} "
          if num == 1: text "reply"
          else: text "replies"
      renderLinks(thread.boardSlug, thread.id, links)
    renderContent("thread-content", thread.parsedContent, thread)


proc renderReply(db: DbConn, reply: Reply, thread: Thread): VNode =
  let links = db.getLinks(reply)
  return buildHtml(tdiv(class="reply", id = $reply.id)):
    if reply.picFormat.isSome():
      let picUrl = getPostPicUrl(fmt"{reply.id}.{reply.pic_format.get()}")
      a(href=picUrl, class="reply-pic-anchor"):
        img(class="reply-pic", src=picUrl)
    else:
      a(class="reply-pic-anchor"): text "text only"

    tdiv(class="reply-header"):
      a(href=fmt"#{reply.id}", class="permalink"):
        text fmt"#{reply.id}"
      time(datetime=reply.createdAt & "+00:00"): text reply.createdAt & " UTC"
      renderLinks(thread.boardSlug, thread.id, links)
    renderContent("reply-content", reply.parsedContent, thread)

proc renderReplies*(db: DbConn, replies: seq[Reply], thread: Thread): VNode =
  return buildHtml(tdiv(class="replies")):
    for reply in replies:
      db.renderReply(reply, thread)
    if len(replies) == 0:
      p(): text "No replies yet."
