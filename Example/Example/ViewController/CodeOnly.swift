import UIKit
import MarkdownView

class CodeOnlySampleViewController: UIViewController {
  
  init() {
    super.init(nibName: nil, bundle: nil)
    view.backgroundColor = .systemBackground
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()

    let mdView = MarkdownView()
    view.addSubview(mdView)
    mdView.translatesAutoresizingMaskIntoConstraints = false
    mdView.topAnchor.constraint(equalTo: topLayoutGuide.topAnchor).isActive = true
    mdView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
    mdView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    mdView.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor).isActive = true

    let path = Bundle.main.path(forResource: "sample", ofType: "md")!

    let url = URL(fileURLWithPath: path)
    let markdown = try! String(contentsOf: url, encoding: String.Encoding.utf8)
    mdView.load(markdown: markdown, enableImage: true)

  }

}
