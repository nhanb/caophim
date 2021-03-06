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
      link(rel="icon", href="/favicon.png", sizes="32x32", `type`="image/png")
      link(rel="icon", href="/favicon.svg", sizes="any", `type`="image/svg+xml")
      link(rel="stylesheet", href="/css/reset.css")
      link(rel="stylesheet", href="/css/style.css")
    body:
      element
      script(src="/js/main.js")

  return "<!DOCTYPE html>\n" & $html


proc renderContentNode(node: ContentNode, thread: Thread): VNode =
  case node.kind
  of P:
    return buildHtml(p):
      for child in node.pChildren:
        renderContentNode(child, thread)
  of Br: return buildHtml(br())
  of Text: return text node.textStr
  of Quote:
    return buildHtml(span(class="greentext")): text node.quoteStr
  of Link:
    let class =
      if $node.linkThreadId != thread.id: "cross-link"
      elif $node.linkPostId == thread.id: "op-link"
      else: ""
    return buildHtml(a(href=node.linkHref, class=class)): text node.linkText
  of Hyperlink:
    return buildHtml(a(href=node.url)): text node.url
  of YoutubeLink:
    let url = fmt"https://youtu.be/{node.ytid}"
    return buildHtml(span(class="youtube-wrapper")):
      a(href=url, class="youtube-link", ytid=node.ytid): text url


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
      a(
        href=fmt"/{boardSlug}/{threadId}/#p{id}",
        class="quote-link",
        `quoted-id`= $id,
      ):
        text fmt">>{id}"


proc renderThread*(db: DbConn, thread: Thread): VNode =
  let picUrl = getPostPicUrl(thread.id, $thread.pic_format)
  let thumbUrl = getPostThumbUrl(thread.id, $thread.pic_format)
  let links = db.getLinks(thread)
  return buildHtml(tdiv(class="thread", id=fmt"p{thread.id}")):
    tdiv(class="thread-header"):
      a(href=fmt"/{thread.boardSlug}/{thread.id}/#p{thread.id}", class="permalink"):
        text fmt"Thread #{thread.id}"
      time(datetime=thread.createdAt & "+00:00"): text thread.createdAt & " UTC"
      if thread.numReplies.isSome():
        text ", "
        let num = thread.numReplies.get()
        let replies_text = if num == 1: "reply" else: "replies"
        if num == 0:
          span(class="num-replies"): text fmt"{num} {replies_text}"
        else:
          strong(class="num-replies"): text fmt"{num} {replies_text}"
      renderLinks(thread.boardSlug, thread.id, links)
    a(href=picUrl, class="thread-pic-anchor"):
      img(class="thread-pic", src=thumbUrl, thumbsrc=thumbUrl, picsrc=picUrl)
    renderContent("thread-content", thread.parsedContent, thread)


proc renderReply(db: DbConn, reply: Reply, thread: Thread): VNode =
  let links = db.getLinks(reply)
  return buildHtml(tdiv(class="reply", id=fmt"p{reply.id}")):
    tdiv(class="reply-header"):
      a(href=fmt"#p{reply.id}", class="permalink"):
        text fmt"Reply #{reply.id}"
      time(datetime=reply.createdAt & "+00:00"): text reply.createdAt & " UTC"
      renderLinks(thread.boardSlug, thread.id, links)

    if reply.picFormat.isSome():
      let picUrl = getPostPicUrl(reply.id, $reply.pic_format.get())
      let thumbUrl = getPostThumbUrl(reply.id, $reply.pic_format.get())
      a(href=picUrl, class="reply-pic-anchor"):
        img(class="reply-pic", src=thumbUrl, thumbsrc=thumbUrl, picsrc=picUrl)
    else:
      a(class="reply-pic-anchor text-only"): text "[text only]"

    renderContent("reply-content", reply.parsedContent, thread)

proc renderReplies*(db: DbConn, replies: seq[Reply], thread: Thread): VNode =
  return buildHtml(tdiv(class="replies")):
    for reply in replies:
      db.renderReply(reply, thread)
    if len(replies) == 0:
      p(class="no-replies"): text "No replies yet."
