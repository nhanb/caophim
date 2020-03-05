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

function pasteablePic() {
  const imgTypes = [
    "image/gif",
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp"
  ];
  document
    .querySelectorAll(".create-thread-form, .create-reply-form")
    .forEach(form => {
      const fileInput = form.querySelector("input[type=file]");
      const previewImg = form.querySelector("img");

      const updatePreviewImg = () => {
        var reader = new FileReader();
        reader.onload = function(e) {
          previewImg.src = e.target.result;
        };
        reader.readAsDataURL(fileInput.files[0]);
      };

      // In case of refresh/back and browser still keeps the file input:
      if (fileInput.files.length === 1) {
        updatePreviewImg();
      }

      // When user clicks on the file input and chooses a file normally:
      fileInput.addEventListener("change", updatePreviewImg);

      // Now the actual on clipboard paste handler:
      form.addEventListener("paste", e => {
        const files = e.clipboardData.files;
        if (files.length === 1 && imgTypes.includes(files[0].type)) {
          fileInput.files = files;
          updatePreviewImg();
        }
      });
    });
}

window.addEventListener("DOMContentLoaded", event => {
  toggleableThumbnails();
  youtubePlayer();
  pasteablePic();
});
