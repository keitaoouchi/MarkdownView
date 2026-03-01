import MarkdownIt from "markdown-it";
import { full as emoji } from "markdown-it-emoji";

export function initRenderer(hljs) {
  const registeredPlugins = [];
  const markdownRendererCache = {
    imageEnabled: null,
    imageDisabled: null,
  };
  let heightPostAnimationFrameId = null;
  let lastPostedDocumentHeight = null;

  const createMarkdownRenderer = ({ enableImage = true } = {}) => {
    const markdown = new MarkdownIt({
      html: true,
      breaks: true,
      linkify: true,
    });

    markdown.use(emoji);
    registeredPlugins.forEach((plugin) => markdown.use(plugin));

    if (!enableImage) {
      markdown.disable("image");
    }

    return markdown;
  };

  const resetMarkdownRendererCache = () => {
    markdownRendererCache.imageEnabled = null;
    markdownRendererCache.imageDisabled = null;
  };

  const getMarkdownRenderer = (enableImage = true) => {
    const cacheKey = enableImage ? "imageEnabled" : "imageDisabled";

    if (markdownRendererCache[cacheKey] == null) {
      markdownRendererCache[cacheKey] = createMarkdownRenderer({ enableImage });
    }

    return markdownRendererCache[cacheKey];
  };

  const measureDocumentHeight = () => {
    var _body = document.body;
    var _html = document.documentElement;
    return Math.max(
      _body.scrollHeight,
      _body.offsetHeight,
      _html.clientHeight,
      _html.scrollHeight,
      _html.offsetHeight
    );
  };

  const flushDocumentHeight = () => {
    const height = measureDocumentHeight();

    if (height === lastPostedDocumentHeight) {
      return;
    }

    lastPostedDocumentHeight = height;
    window?.webkit?.messageHandlers?.updateHeight?.postMessage(height);
  };

  const postDocumentHeight = () => {
    if (heightPostAnimationFrameId != null) {
      return;
    }

    const schedule = window?.requestAnimationFrame ?? ((callback) => setTimeout(callback, 0));
    heightPostAnimationFrameId = schedule(() => {
      heightPostAnimationFrameId = null;
      flushDocumentHeight();
    });
  };

  window.usePlugin = (plugin) => {
    registeredPlugins.push(plugin);
    resetMarkdownRendererCache();
  };

  window.renderMarkdown = (payload = {}) => {
    if (!payload || typeof payload !== "object") {
      return;
    }

    const markdownText = typeof payload.markdown === "string" ? payload.markdown : null;
    const enableImage = payload.enableImage !== false;

    if (markdownText == null) {
      return;
    }

    const markdownRenderer = getMarkdownRenderer(enableImage);
    let html = markdownRenderer.render(markdownText);

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
      hljs.highlightElement(code);
    });

    postDocumentHeight();
  };

  window.showMarkdown = (percentEncodedMarkdown, enableImage = true) => {
    if (typeof percentEncodedMarkdown !== "string") {
      return;
    }

    let markdownText = percentEncodedMarkdown;
    try {
      markdownText = decodeURIComponent(percentEncodedMarkdown);
    } catch (_) {
      markdownText = percentEncodedMarkdown;
    }

    window.renderMarkdown({
      markdown: markdownText,
      enableImage,
    });
  };
}
