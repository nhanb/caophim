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
proc renderContent(class: string, content: string, topic: Topic): VNode =

  # If line is in "quote" format, render link to quoted topic/reply
  proc renderLine(line: string): VNode =
    buildHtml(span):
      if line.match(re(r"^>>\d+$")): # quoting topic
        let topicId = line[2..^1]
        if topicId == topic.id:
          a(href="#topic-top"): text line
        else:
          a(href=fmt"/{topic.boardSlug}/{topicId}/"): text line
      elif line.match(re(r"^>>\d+/\d+$")): # quoting reply
        let topicId = line[2..line.find("/")-1]
        let replyId = line[line.find("/")+1..^1]
        a(href=fmt"/{topic.boardSlug}/{topicId}/#{replyId}"): text line
      else:
        text line

  return buildHtml(tdiv(class=class)):
      for paragraph in content.split("\c\n\c\n"):
        p():
          for line in paragraph.split("\c\n"):
            renderLine(line)
            verbatim("<br/>")


proc renderTopic*(topic: Topic): VNode =
  let picUrl = fmt"/pics/{topic.id}.{topic.pic_format}"
  return buildHtml(tdiv(class="topic")):
    a(href=picUrl, class="topic-pic-anchor"):
      img(class="topic-pic", src=picUrl)
    tdiv(class="topic-header"):
      a(href=fmt"/{topic.boardSlug}/{topic.id}/", id="topic-top"):
        text "[" & topic.id & "]"
      time(datetime=topic.createdAt): text topic.createdAt
      if topic.numReplies.isSome():
        let num = topic.numReplies.get()
        text ", "
        span():
          text fmt"{num} "
          if num == 1: text "reply"
          else: text "replies"
    renderContent("topic-content", topic.content, topic)


proc renderReply(reply: Reply, topic: Topic): VNode =
  return buildHtml(tdiv(class="reply")):
    if reply.picFormat.isSome():
      let picUrl = fmt"/pics/r/{reply.id}.{reply.pic_format.get()}"
      a(href=picUrl, class="reply-pic-anchor"):
        img(class="reply-pic", src=picUrl)
    else:
      a(class="reply-pic-anchor"): text "text only"

    tdiv(class="reply-header"):
      a(href=fmt"#{reply.id}", id = $reply.id):
        text fmt"[{reply.topicId}/{reply.id}]"
      time(datetime=reply.createdAt): text reply.createdAt
    renderContent("reply-content", reply.content, topic)

proc renderReplies*(replies: seq[Reply], topic: Topic): VNode =
  return buildHtml(tdiv(class="replies")):
    for reply in replies:
      renderReply(reply, topic)
    if len(replies) == 0:
      p(): text "No replies yet."
