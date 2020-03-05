function toggleableThumbnails() {
  document
    .querySelectorAll(".thread-pic-anchor, .reply-pic-anchor")
    .forEach(anchor => {
      const img = anchor.firstElementChild;
      if (!img) return; // ignore text-only anchors

      // OnClick: toggle image between full and thumbnail size
      anchor.addEventListener("click", event => {
        const src = img.getAttribute("src");
        const thumbsrc = img.getAttribute("thumbsrc");
        const picsrc = img.getAttribute("picsrc");
        if (src === thumbsrc) {
          // Fade thumbnail when full pic is being loaded.
          // Looks a bit messy because it also needs to behave sensibly when user
          // clicks the second time before full pic can be loaded.
          if (img.getAttribute("fullPicIsLoaded") !== "1") {
            img.style.opacity = "0.5";
            const onload = function(evt) {
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
}

function youtubePlayer() {
  document.querySelectorAll(".youtube-wrapper").forEach(wrapper => {
    const youtubeId = wrapper.firstChild.getAttribute("ytid");
    const btn = document.createElement("a");
    btn.innerHTML = "↳load player";
    btn.setAttribute("class", "load-player-button");
    wrapper.appendChild(btn);
    btn.onclick = () => {
      const iframe = document.createElement("iframe");
      iframe.setAttribute(
        "src",
        `https://www.youtube-nocookie.com/embed/${youtubeId}`
      );
      iframe.setAttribute("allowfullscreen", "allowfullscreen");
      iframe.setAttribute("class", "youtube-iframe");
      wrapper.appendChild(document.createElement("br"));
      wrapper.appendChild(iframe);
      btn.remove();
    };
  });
}

window.addEventListener("DOMContentLoaded", event => {
  toggleableThumbnails();
  youtubePlayer();
});
