import UIKit
import MarkdownView

class Example1ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let mdView = MarkdownView()
        view.addSubview(mdView)
        mdView.translatesAutoresizingMaskIntoConstraints = false
        
        // Apply appropriate constraints
        if #available(iOS 10.0, *) {
            mdView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
            mdView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        } else if #available(OSX 10.15, *) {
            print("loading osx constraints")
            mdView.topAnchor.constraint(equalTo: topLayoutGuide.topAnchor).isActive = true
            mdView.topAnchor.constraint(equalTo: topLayoutGuide.topAnchor).isActive = true
        } else {
             // TODO: figure out if other versions have specific reqs
            #if DEBUG
            print("unhandled OS / version detected, layout contstraints will not be set")
            #endif
         }
         mdView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
         mdView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        
        // Load sample
        let path = Bundle.main.path(forResource: "sample", ofType: "md")!
        let url = URL(fileURLWithPath: path)
        let markdown = try! String(contentsOf: url, encoding: String.Encoding.utf8)
        mdView.load(markdown: markdown, enableImage: true)
  }
}

