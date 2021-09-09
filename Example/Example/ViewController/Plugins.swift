import UIKit
import MarkdownView

class PluginsSampleViewController: UIViewController {
  
  init() {
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    
    let plugins = [
      URL(string: "https://cdnjs.cloudflare.com/ajax/libs/markdown-it-footnote/3.0.3/markdown-it-footnote.js")!,
      URL(string: "https://cdn.jsdelivr.net/npm/markdown-it-sub@1.0.0/index.min.js")!,
      URL(string: "https://cdn.jsdelivr.net/npm/markdown-it-sup@1.0.0/index.min.js")!,
    ].map {
      try! String(contentsOf: $0, encoding: .utf8)
    }

    let md = MarkdownView()
    view.addSubview(md)
    md.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      md.topAnchor.constraint(equalTo: view.topAnchor),
      md.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      md.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      md.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])

    let markdown = """
    # Plugins Sample
    ## Footnote
    Here is a footnote reference,[^1] and another.[^longnote]

    [^1]: Here is the footnote.

    [^longnote]: Here's one with multiple blocks.

        Subsequent paragraphs are indented to show that they
    belong to the previous footnote.
    
    ## Sub
    H~2~0
    
    ## Sup
    29^th^
    """
    md.load(markdown: markdown, enableImage: false, plugins: plugins)
  }

}
