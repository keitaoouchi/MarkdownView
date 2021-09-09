import UIKit
import MarkdownView

class CustomCssSampleViewController: UIViewController {
  
  init() {
    super.init(nibName: nil, bundle: nil)
    view.backgroundColor = .systemBackground
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let css = [
      "h1 { color:red; }",
      "h2 { color:green; }",
      "h3 { color:blue; }",
    ].joined(separator: "\n")

    let md = MarkdownView()
    view.addSubview(md)
    md.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      md.topAnchor.constraint(equalTo: view.topAnchor),
      md.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      md.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      md.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])

    let markdown = ["# h1 title", "## h2 title", "### h3 title"].joined(separator: "\n")
    md.load(markdown: markdown, enableImage: false, css: css, plugins: nil)
  }

}
