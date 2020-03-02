// Toggle pic/thumbnail on click
document
  .querySelectorAll(".thread-pic-anchor, .reply-pic-anchor")
  .forEach(anchor => {
    anchor.addEventListener("click", event => {
      let img = anchor.firstElementChild;
      let src = img.getAttribute("src");
      let thumbsrc = img.getAttribute("thumbsrc");
      let picsrc = img.getAttribute("picsrc");
      if (src === thumbsrc) {
        img.setAttribute("src", picsrc);
      } else {
        img.setAttribute("src", thumbsrc);
      }

      event.preventDefault();
    });
  });
