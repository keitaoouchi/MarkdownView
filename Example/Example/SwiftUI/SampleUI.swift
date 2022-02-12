import SwiftUI
import MarkdownView

struct SampleUI: View {
  var body: some View {
    ScrollView {
      Text("Header")
        .frame(maxWidth: .infinity, idealHeight: 44)
        .background(Color.red)

        
      MarkdownUI(body: markdown)
      
      Text("Footer")
        .frame(maxWidth: .infinity, idealHeight: 44)
        .background(Color.red)
    }
  }
  
  private var markdown: String {
    let path = Bundle.main.path(forResource: "sample", ofType: "md")!
    let url = URL(fileURLWithPath: path)
    return try! String(contentsOf: url, encoding: String.Encoding.utf8)
  }
}
