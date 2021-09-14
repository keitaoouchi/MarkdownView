import UIKit
import MarkdownView

class RemoteStyleSheetsSampleViewController: UIViewController {
  
  init() {
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

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
    # Katex
    
    $\\sqrt{3x-1}+(1+x)^2$
    """
    md.load(markdown: markdown, plugins: [js], stylesheets: [stylesheet])
  }

}

extension RemoteStyleSheetsSampleViewController {
  var js: String {
    let url = URL(string: "https://raw.githubusercontent.com/keitaoouchi/markdownview-sample-plugin/master/dist/dst.js")!
    return try! String(contentsOf: url)
  }
  
  var stylesheet: URL {
    URL(string: "https://cdn.jsdelivr.net/npm/katex@0.13.18/dist/katex.min.css")!
  }
}
