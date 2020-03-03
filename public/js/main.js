// Toggle pic/thumbnail on click
document
  .querySelectorAll(".thread-pic-anchor, .reply-pic-anchor")
  .forEach(anchor => {
    let img = anchor.firstElementChild;
    if (!img) return; // ignore text-only anchors

    // OnClick: toggle image between full and thumbnail size
    anchor.addEventListener("click", event => {
      let src = img.getAttribute("src");
      let thumbsrc = img.getAttribute("thumbsrc");
      let picsrc = img.getAttribute("picsrc");
      if (src === thumbsrc) {
        // Fade thumbnail when full pic is being loaded.
        // Looks a bit messy because it also needs to behave sensibly when user
        // clicks the second time before full pic can be loaded.
        if (img.getAttribute("fullPicIsLoaded") !== "1") {
          img.style.opacity = "0.5";
          let onload = function(evt) {
            img.style.opacity = "1";
            if (img.src === picsrc) {
              img.setAttribute("fullPicIsLoaded", "1");
              img.removeEventListener("load", onload);
            }
          };
          img.addEventListener("load", onload);
        }
        img.setAttribute("src", picsrc);
      } else {
        img.setAttribute("src", thumbsrc);
      }

      event.preventDefault();
    });
  });
