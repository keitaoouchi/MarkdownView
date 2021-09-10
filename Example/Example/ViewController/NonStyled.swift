import UIKit
import MarkdownView

class NonStyledSampleViewController: UIViewController {
  
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
    # h1 Heading 8-)
    ## h2 Heading
    ### h3 Heading
    #### h4 Heading
    ##### h5 Heading
    ###### h6 Heading
    """
    let css = try! String(contentsOf: URL(string: "https://raw.githubusercontent.com/gkroon/dracula-css/master/dracula.css")!, encoding: .utf8)
    md.load(markdown: markdown, css: css, styled: false)
  }

}
