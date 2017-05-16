import UIKit
import MarkdownView
import WebKit
import SafariServices

class Example3ViewController: UIViewController {

  @IBOutlet weak var mdView: MarkdownView!
  @IBOutlet weak var mdViewHeight: NSLayoutConstraint!

  override func viewDidLoad() {
    super.viewDidLoad()

    mdView.isScrollEnabled = false

    mdView.onRendered = { [weak self] height in
      self?.mdViewHeight.constant = height
      self?.view.setNeedsLayout()
    }

    mdView.onTouchLink = { [weak self] request in
      guard let url = request.url else { return false }

      if url.scheme == "file" {
        return true
      } else if url.scheme == "https" {
        let safari = SFSafariViewController(url: url)
        self?.navigationController?.pushViewController(safari, animated: true)
        return false
      } else {
        return false
      }
    }

    let session = URLSession(configuration: .default)
    let url = URL(string: "https://raw.githubusercontent.com/matteocrippa/awesome-swift/master/README.md")!
    let task = session.dataTask(with: url) { [weak self] data, res, error in
      let str = String(data: data!, encoding: String.Encoding.utf8)
      DispatchQueue.main.async {
        self?.mdView.load(markdown: str)
      }
    }
    task.resume()
  }
  
}
