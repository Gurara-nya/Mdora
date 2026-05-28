import Foundation
import WebKit
import MdoraCore
import AppKit

final class PDFExporter: NSObject, WKNavigationDelegate {
    private static var activeExporters: Set<PDFExporter> = []

    private let html: String
    private let baseURL: URL?
    private let destinationURL: URL
    private let completion: (Result<Void, Error>) -> Void
    private var webView: WKWebView?

    private init(html: String, baseURL: URL?, destinationURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        self.html = html
        self.baseURL = baseURL
        self.destinationURL = destinationURL
        self.completion = completion
        super.init()
    }

    static func export(markdown: String, title: String, baseURL: URL?, destinationURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let html = MarkdownHTMLRenderer.renderDocument(markdown, title: title)
        let exporter = PDFExporter(html: html, baseURL: baseURL, destinationURL: destinationURL, completion: completion)
        activeExporters.insert(exporter)

        DispatchQueue.main.async {
            exporter.start()
        }
    }

    private func start() {
        let configuration = WKWebViewConfiguration()
        // Enable file access permissions for local subresources if needed
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView

        // Load the HTML content using the base URL
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait briefly for images and layout to render fully
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self else { return }
            self.generatePDF()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completion(.failure(error))
        PDFExporter.activeExporters.remove(self)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        completion(.failure(error))
        PDFExporter.activeExporters.remove(self)
    }

    private func generatePDF() {
        guard let webView = webView else {
            completion(.failure(NSError(domain: "PDFExporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "WebView was deallocated"])))
            PDFExporter.activeExporters.remove(self)
            return
        }

        let config = WKPDFConfiguration()
        webView.createPDF(configuration: config) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let data):
                do {
                    try data.write(to: self.destinationURL)
                    self.completion(.success(()))
                } catch {
                    self.completion(.failure(error))
                }
            case .failure(let error):
                self.completion(.failure(error))
            }

            PDFExporter.activeExporters.remove(self)
        }
    }
}
