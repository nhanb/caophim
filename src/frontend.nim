import strformat, strutils, options, re
import karax / [karaxdsl, vdom]
import database


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


# TODO: consider storing pre-processed paragraphs and links instead
# of processing on every view here
proc renderContent(class: string, content: string, thread: Thread): VNode =

  # If line is in "quote" format, render link to quoted thread/reply
  proc renderLine(line: string): VNode =
    buildHtml(span):
      if line.match(re(r"^>>\d+$")): # quoting thread
        let threadId = line[2..^1]
        if threadId == thread.id:
          a(href="#" & thread.id): text line
        else:
          a(class="cross-link", href=fmt"/{thread.boardSlug}/{threadId}/"): text line
      else:
        text line

  return buildHtml(tdiv(class=class)):
      for paragraph in content.split("\c\n\c\n"):
        p():
          for line in paragraph.split("\c\n"):
            renderLine(line)
            verbatim("<br/>")


proc renderThread*(thread: Thread): VNode =
  let picUrl = fmt"/pics/{thread.id}.{thread.pic_format}"
  return buildHtml(tdiv(class="thread")):
    a(href=picUrl, class="thread-pic-anchor"):
      img(class="thread-pic", src=picUrl)
    tdiv(class="thread-header"):
      a(href=fmt"/{thread.boardSlug}/{thread.id}/", id=thread.id):
        text "/" & thread.id & "/"
      time(datetime=thread.createdAt & "+00:00"): text thread.createdAt & " UTC"
      if thread.numReplies.isSome():
        let num = thread.numReplies.get()
        text ", "
        span(class=if num == 0: "" else: "bold"):
          text fmt"{num} "
          if num == 1: text "reply"
          else: text "replies"
    renderContent("thread-content", thread.content, thread)


proc renderReply(reply: Reply, thread: Thread): VNode =
  return buildHtml(tdiv(class="reply", id = $reply.id)):
    if reply.picFormat.isSome():
      let picUrl = fmt"/pics/{reply.id}.{reply.pic_format.get()}"
      a(href=picUrl, class="reply-pic-anchor"):
        img(class="reply-pic", src=picUrl)
    else:
      a(class="reply-pic-anchor"): text "text only"

    tdiv(class="reply-header"):
      a(href=fmt"#{reply.id}"):
        text fmt"#{reply.id}"
      time(datetime=reply.createdAt & "+00:00"): text reply.createdAt & " UTC"
    renderContent("reply-content", reply.content, thread)

proc renderReplies*(replies: seq[Reply], thread: Thread): VNode =
  return buildHtml(tdiv(class="replies")):
    for reply in replies:
      renderReply(reply, thread)
    if len(replies) == 0:
      p(): text "No replies yet."
