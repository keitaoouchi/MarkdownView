import $ from 'jquery'
import hljs from 'highlight.js'
import MarkdownIt from 'markdown-it'
import 'bootstrap/dist/css/bootstrap.css'
import './../css/gist.css'
import './../css/github.css'
import './../css/index.css'

window.showMarkdown = (markdownText) => {

  if (!markdownText) {
    return
  }

  let markdown = new MarkdownIt({
    html: true,
    breaks: true,
    linkify: true,
    highlight: function(code){
        return hljs.highlightAuto(code).value;
    }
  })

  let html = markdown.render(markdownText)
  $('#contents').html(html)
  $('table').addClass('table')
  $('pre code').each((i, block) => hljs.highlightBlock(block))

}
