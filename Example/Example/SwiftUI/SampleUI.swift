import SwiftUI
import MarkdownView

private final class MarkdownListHeightCache {
    static let shared = MarkdownListHeightCache()

    private struct Key: Hashable {
        let markdown: String
        let widthBucket: Int
    }

    private var storage: [Key: CGFloat] = [:]
    private let lock = NSLock()

    private init() {}

    func height(for markdown: String, width: CGFloat) -> CGFloat? {
        guard width > 0 else { return nil }
        let key = Key(markdown: markdown, widthBucket: widthBucket(for: width))
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func store(height: CGFloat, for markdown: String, width: CGFloat) {
        guard width > 0, height > 0 else { return }
        let key = Key(markdown: markdown, widthBucket: widthBucket(for: width))
        lock.lock()
        storage[key] = height
        lock.unlock()
    }

    private func widthBucket(for width: CGFloat) -> Int {
        Int((width * 2).rounded())
    }
}

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

struct SampleListUI: View {
    private let items = MarkdownListItem.makeLargeDataset(count: 80)

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(items) { item in
                    MarkdownListRow(item: item)
                    Divider()
                }
            }
        }
        .navigationTitle("SwiftUI LazyVStack (80)")
    }
}

private struct MarkdownListRow: View {
    let item: MarkdownListItem
    @State private var contentHeight: CGFloat = 1
    @State private var markdownWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.headline)

            MarkdownUI(body: item.markdown)
                .onRendered { height in
                    guard abs(contentHeight - height) > 0.5 else { return }
                    contentHeight = height
                    MarkdownListHeightCache.shared.store(
                        height: height,
                        for: item.markdown,
                        width: markdownWidth
                    )
                }
                .onTouchLink { link in
                    print(link)
                    return false
                }
                .frame(height: contentHeight)
                .clipped()
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                updateMarkdownWidth(proxy.size.width)
                            }
                            .onChange(of: proxy.size.width) { newWidth in
                                updateMarkdownWidth(newWidth)
                            }
                    }
                )
        }
        .onChange(of: item.id) { _ in
            applyCachedHeightOrReset()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func updateMarkdownWidth(_ width: CGFloat) {
        guard abs(markdownWidth - width) > 0.5 else { return }
        markdownWidth = width
        applyCachedHeightOrReset()
    }

    private func applyCachedHeightOrReset() {
        if let cachedHeight = MarkdownListHeightCache.shared.height(
            for: item.markdown,
            width: markdownWidth
        ) {
            contentHeight = cachedHeight
        } else {
            contentHeight = 1
        }
    }
}

private struct MarkdownListItem: Identifiable {
    let id: String
    let title: String
    let markdown: String

    static func makeLargeDataset(count: Int) -> [MarkdownListItem] {
        let teams = ["iOS", "Backend", "Design", "QA", "Infra", "Data"]
        let statuses = ["Draft", "In Review", "Scheduled", "Published", "Blocked"]
        let priorities = ["Low", "Medium", "High"]
        let topics = [
            "Release Notes",
            "Incident Summary",
            "Sprint Plan",
            "Migration Guide",
            "API Update",
            "Onboarding Memo",
            "Performance Report"
        ]
        let actions = [
            "Validate rendering output on iPhone SE and iPad",
            "Confirm external links open in the expected flow",
            "Check code block highlighting for Swift and JSON",
            "Measure scroll smoothness during rapid navigation",
            "Review row height updates after async rendering"
        ]

        return (1...count).map { index in
            let team = teams[(index - 1) % teams.count]
            let status = statuses[(index - 1) % statuses.count]
            let priority = priorities[(index - 1) % priorities.count]
            let topic = topics[(index - 1) % topics.count]
            let estimate = 15 + (index % 8) * 5
            let action1 = actions[(index - 1) % actions.count]
            let action2 = actions[index % actions.count]

            let markdown = """
      ## \(topic) #\(index)

      **Owner:** \(team) Team
      **Status:** \(status)
      **Priority:** \(priority)

      This row simulates a realistic note body for list rendering tests. It contains a few inline styles like **bold text**, _emphasis_, and a [reference link](https://example.com/docs/\(index)).

      ### Summary
      - Ticket: `MD-\(1000 + index)`
      - Estimated effort: \(estimate) min
      - Scope: rendering, sizing, scrolling, and row reuse

      ### Actions
      1. \(action1)
      2. \(action2)
      3. Capture regressions if row height changes after reuse.

      > Reuse test note: rows should keep stable layout while the WKWebView content finishes measuring.

      ```swift
      struct RenderJob {
        let id = "\(index)"
        let status = "\(status.lowercased())"
      }
      ```
      """

            return MarkdownListItem(
                id: "row-\(index)",
                title: "\(team) / \(topic)",
                markdown: markdown
            )
        }
    }
}
