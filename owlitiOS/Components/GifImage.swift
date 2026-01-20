import SwiftUI
import WebKit

struct GifImage: UIViewRepresentable {
    private let name: String

    init(_ name: String) {
        self.name = name
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false // Transparent
        webView.backgroundColor = .clear // Transparent
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = Bundle.main.url(forResource: name, withExtension: "gif") {
             do {
                 let data = try Data(contentsOf: url)
                 let base64 = data.base64EncodedString()
                 
                 // CSS: 
                 // object-fit: contain -> Preserves aspect ratio, fits within screen (likely black bars if aspect mismatch)
                 // background-color: black -> Ensures bars are black
                 let html = """
                 <html>
                 <head>
                 <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                 <style>
                 body { margin: 0; padding: 0; background: black; height: 100%; width: 100%; overflow: hidden; display: flex; align-items: center; justify-content: center; }
                 img { width: 100%; height: 100%; object-fit: contain; }
                 </style>
                 </head>
                 <body>
                 <img src="data:image/gif;base64,\(base64)" />
                 </body>
                 </html>
                 """
                 
                 uiView.loadHTMLString(html, baseURL: nil)
             } catch {
                 print("Failed to load GIF data: \(error)")
             }
        }
    }
}
