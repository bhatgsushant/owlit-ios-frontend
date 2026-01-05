import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    let token: String?

    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        // Append token if possible, though SFSafariView shares system cookies so the user might already be logged in if they used Safari.
        var requestUrl = url
        if let token = token {
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                var items = components.queryItems ?? []
                if !items.contains(where: { $0.name == "access_token" }) {
                    items.append(URLQueryItem(name: "access_token", value: token))
                }
                components.queryItems = items
                if let newUrl = components.url {
                    requestUrl = newUrl
                }
            }
        }
        
        let controller = SFSafariViewController(url: requestUrl)
        // customizing colors if needed
        controller.preferredControlTintColor = .systemBlue 
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
        // No update needed
    }
}
