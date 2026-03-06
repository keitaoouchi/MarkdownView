import UIKit
import WebKit

final class MarkdownEventBridge: NSObject, WKScriptMessageHandler {
    private let onHeightUpdate: (CGFloat) -> Void

    init(onHeightUpdate: @escaping (CGFloat) -> Void) {
        self.onHeightUpdate = onHeightUpdate
    }

    func attach(to userContentController: WKUserContentController) {
        userContentController.removeScriptMessageHandler(forName: "updateHeight")
        userContentController.add(self, name: "updateHeight")
    }

    func detach(from userContentController: WKUserContentController) {
        userContentController.removeScriptMessageHandler(forName: "updateHeight")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let height = message.body as? CGFloat else { return }
        onHeightUpdate(height)
    }
}
