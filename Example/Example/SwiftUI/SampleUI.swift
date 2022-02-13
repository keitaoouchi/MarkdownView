import SwiftUI
import MarkdownView

struct SampleUI: View {
  var body: some View {
    ScrollView {
      MarkdownUI(body: markdown)
        .onTouchLink { link in
          print(link)
          return false
        }
        .onRendered { height in
          print(height)
        }
    }
  }
  
  private var markdown: String {
    let path = Bundle.main.path(forResource: "sample", ofType: "md")!
    let url = URL(fileURLWithPath: path)
    return try! String(contentsOf: url, encoding: String.Encoding.utf8)
  }
}
