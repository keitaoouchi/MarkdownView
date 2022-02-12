import hljs from "highlight.js";
import MarkdownIt from "markdown-it";
import emoji from "markdown-it-emoji";
import "./../css/bootstrap.css";
import "./../css/gist.css";
import "./../css/github.css";
import "./../css/index.css";

let markdown = new MarkdownIt({
  html: true,
  breaks: true,
  linkify: true,
  highlight: function (code) {
    return hljs.highlightAuto(code).value;
  },
});

const postDocumentHeight = () => {
  var _body = document.body;
  var _html = document.documentElement;
  var height = Math.max(
    _body.scrollHeight,
    _body.offsetHeight,
    _html.clientHeight,
    _html.scrollHeight,
    _html.offsetHeight
  );
  console.log(height)
  window?.webkit?.messageHandlers?.updateHeight?.postMessage(height);
};

markdown.use(emoji);

window.usePlugin = (plugin) => markdown.use(plugin);

window.showMarkdown = (percentEncodedMarkdown, enableImage = true) => {
  if (!percentEncodedMarkdown) {
    return;
  }

  const markdownText = decodeURIComponent(percentEncodedMarkdown);

  if (!enableImage) {
    markdown = markdown.disable("image");
  }

  let html = markdown.render(markdownText);

  document.getElementById("contents").innerHTML = html;

  var imgs = document.querySelectorAll("img");

  imgs.forEach((img) => {
    img.loading = "lazy";
    img.onload = () => {
      postDocumentHeight();
    };
  });

  window.imgs = imgs;

  let tables = document.querySelectorAll("table");

  tables.forEach((table) => {
    table.classList.add("table");
  });

  let codes = document.querySelectorAll("pre code");

  codes.forEach((code) => {
    hljs.highlightBlock(code);
  });

  postDocumentHeight();
};
