import UIKit
import MarkdownView

class Example1ViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()

    let mdView = MarkdownView()
    view.addSubview(mdView)
    mdView.translatesAutoresizingMaskIntoConstraints = false
    mdView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
    mdView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
    mdView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    mdView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

    let session = URLSession(configuration: .default)
    let url = URL(string: "https://raw.githubusercontent.com/matteocrippa/awesome-swift/master/README.md")!
    let task = session.dataTask(with: url) { data, res, error in
      let str = String(data: data!, encoding: String.Encoding.utf8)
      DispatchQueue.main.async {
        mdView.load(markdown: str)
      }
    }
    task.resume()
  }

}

