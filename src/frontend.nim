import strformat, strutils
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


proc renderTopic*(topic: Topic): VNode =
  let picUrl = fmt"/pics/{topic.id}.{topic.pic_format}"
  return buildHtml(tdiv(class="topic")):
    a(href=picUrl, class="topic-pic-anchor"):
      img(class="topic-pic", src=picUrl)
    tdiv(class="topic-header"):
      a(href=fmt"/{topic.boardSlug}/{topic.id}/"):
        text "[" & topic.id & "]"
      time(datetime=topic.createdAt): text topic.createdAt
    tdiv(class="topic-content"):
      # TODO: consider storing pre-processed paragraphs instead
      # of splitting on every view here
      for paragraph in topic.content.split("\c\n\c\n"):
        p():
          for line in paragraph.split("\c\n"):
            text line
            verbatim("<br/>")
