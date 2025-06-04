import Foundation
import WebKit
import UIKit
import AVKit

class WKYTPlayerService: NSObject {
    static let shared = WKYTPlayerService()
    
    private override init() {}
    
    // Create a player view controller that embeds a YouTube video using WKWebView
    func createPlayerViewController(videoId: String) -> UIViewController {
        let playerViewController = WKYTPlayerViewController()
        playerViewController.loadVideo(videoId: videoId)
        return playerViewController
    }
    
    // Extract video ID from YouTube URL
    func extractVideoId(from url: String) -> String? {
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems else {
            return nil
        }
        return queryItems.first(where: { $0.name == "v" })?.value
    }
}

class WKYTPlayerViewController: UIViewController, WKNavigationDelegate {
    private var webView: WKWebView!
    private var loadingIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupLoadingIndicator()
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.backgroundColor = .black
        view.addSubview(webView)
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.center = view.center
        loadingIndicator.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        view.addSubview(loadingIndicator)
    }
    
    func loadVideo(videoId: String) {
        // Create YouTube embed HTML that works well on tvOS
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    background-color: black;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                }
                #player {
                    width: 100%;
                    height: 100%;
                    border: none;
                }
            </style>
        </head>
        <body>
            <iframe id="player"
                    src="https://www.youtube.com/embed/\(videoId)?autoplay=1&playsinline=1&controls=1&modestbranding=1&rel=0"
                    allow="autoplay; encrypted-media"
                    allowfullscreen>
            </iframe>
        </body>
        </html>
        """
        
        loadingIndicator.startAnimating()
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingIndicator.stopAnimating()
        loadingIndicator.removeFromSuperview()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingIndicator.stopAnimating()
        print("🌟 WKYTPlayer: Failed to load video: \(error.localizedDescription)")
        
        // Show error alert
        let alert = UIAlertController(title: "Video Load Error", 
                                    message: "Failed to load YouTube video: \(error.localizedDescription)", 
                                    preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Clean up when leaving
        webView.stopLoading()
    }
} 