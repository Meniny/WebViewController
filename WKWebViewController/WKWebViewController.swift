//
//  WKWebViewController.swift
//  Sample
//
//  Created by Meniny on 2018-01-20.
//  Copyright © 2018年 Meniny. All rights reserved.
//

import UIKit
import WebKit
import JustLayout

fileprivate let estimatedProgressKeyPath = "estimatedProgress"
fileprivate let titleKeyPath = "title"
fileprivate let cookieKey = "Cookie"

fileprivate struct UrlsHandledByApp {
    public static var hosts = ["itunes.apple.com"]
    public static var schemes = ["tel", "mailto", "sms"]
    public static var blank = true
}

@objc public protocol WKWebViewControllerDelegate {
    @objc optional func webViewController(_ controller: WKWebViewController, canDismiss url: URL) -> Bool
    
    @objc optional func webViewController(_ controller: WKWebViewController, didStart url: URL)
    @objc optional func webViewController(_ controller: WKWebViewController, didFinish url: URL)
    @objc optional func webViewController(_ controller: WKWebViewController, didFail url: URL, withError error: Error)
    @objc optional func webViewController(_ controller: WKWebViewController, decidePolicy url: URL, navigationType: NavigationType) -> Bool
}

open class WKWebViewController: UIViewController {
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public init(source: WKWebSource?) {
        super.init(nibName: nil, bundle: nil)
        self.source = source
    }
    
    public init(url: URL) {
        super.init(nibName: nil, bundle: nil)
        self.source = .remote(url)
    }
    
    open var source: WKWebSource?
    /// use `source` instead
    open internal(set) var url: URL?
    open var tintColor: UIColor?

    open var navigationBarBackgroundColor: UIColor?
    open var navigationBarForegroundColor: UIColor?

    open var allowsFileURL = true
    open var delegate: WKWebViewControllerDelegate?
    open var bypassedSSLHosts: [String]?
    open var cookies: [HTTPCookie]?
    open var headers: [String: String]?
    internal var customUserAgent: String? {
        didSet {
            guard let agent = userAgent else {
                return
            }
            webView?.customUserAgent = agent
        }
    }
    
    open var userAgent: String? {
        didSet {
            guard let originalUserAgent = originalUserAgent, let userAgent = userAgent else {
                return
            }
            webView?.customUserAgent = [originalUserAgent, userAgent].joined(separator: " ")
        }
    }
    
    open var pureUserAgent: String? {
        didSet {
            guard let agent = pureUserAgent else {
                return
            }
            webView?.customUserAgent = agent
        }
    }
    
    open var websiteTitleInNavigationBar = true

    private var _adjustFontSizeForNavigationBarLargeTitle = false

    /// Set to `true` if you want to scale down the font size of the navigation bar large title in order to fit on one row.
    @available(iOS 11.0, *) @objc open var adjustFontSizeForNavigationBarLargeTitle: Bool {
        get { return _adjustFontSizeForNavigationBarLargeTitle }
        set { _adjustFontSizeForNavigationBarLargeTitle = newValue }
    }

    open var doneBarButtonItemPosition: NavigationBarPosition = .right
    open var leftNavigaionBarItemTypes: [BarButtonItemType] = []
    open var rightNavigaionBarItemTypes: [BarButtonItemType] = []
    open var toolbarItemTypes: [BarButtonItemType] = [.back, .forward, .reload, .activity]
    
    open var backBarButtonItemImage: UIImage?
    open var forwardBarButtonItemImage: UIImage?
    open var reloadBarButtonItemImage: UIImage?
    open var stopBarButtonItemImage: UIImage?
    open var activityBarButtonItemImage: UIImage?

    fileprivate var webView: WKWebView?
    fileprivate var progressView: UIProgressView?
    
    fileprivate var previousNavigationBarState: (tintColor: UIColor, backgroundColor: UIColor, foregroundColor: UIColor, hidden: Bool) = (.black, .white, .black, false)
    fileprivate var previousToolbarState: (tintColor: UIColor, hidden: Bool) = (.black, false)
    
    lazy fileprivate var originalUserAgent = UIWebView().stringByEvaluatingJavaScript(from: "navigator.userAgent")
    
    lazy fileprivate var backBarButtonItem: UIBarButtonItem = {
        let bundle = Bundle(for: WKWebViewController.self)
        return UIBarButtonItem(image: backBarButtonItemImage ?? UIImage(named: "Back", in: bundle, compatibleWith: nil), style: .plain, target: self, action: #selector(backDidClick(sender:)))
    }()
    
    lazy fileprivate var forwardBarButtonItem: UIBarButtonItem = {
        let bundle = Bundle(for: WKWebViewController.self)
        return UIBarButtonItem(image: forwardBarButtonItemImage ?? UIImage(named: "Forward", in: bundle, compatibleWith: nil), style: .plain, target: self, action: #selector(forwardDidClick(sender:)))
    }()
    
    lazy fileprivate var reloadBarButtonItem: UIBarButtonItem = {
        if let image = reloadBarButtonItemImage {
            return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(reloadDidClick(sender:)))
        } else {
            return UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reloadDidClick(sender:)))
        }
    }()
    
    lazy fileprivate var stopBarButtonItem: UIBarButtonItem = {
        if let image = stopBarButtonItemImage {
            return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(stopDidClick(sender:)))
        } else {
            return UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(stopDidClick(sender:)))
        }
    }()
    
    lazy fileprivate var activityBarButtonItem: UIBarButtonItem = {
        if let image = activityBarButtonItemImage {
            return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(activityDidClick(sender:)))
        } else {
            return UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(activityDidClick(sender:)))
        }
    }()
    
    lazy fileprivate var doneBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneDidClick(sender:)))
    }()
    
    lazy fileprivate var flexibleSpaceBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    }()
    
    deinit {
        webView?.removeObserver(self, forKeyPath: estimatedProgressKeyPath)
        if websiteTitleInNavigationBar {
            webView?.removeObserver(self, forKeyPath: titleKeyPath)
        }
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.white

        self.extendedLayoutIncludesOpaqueBars = true
        self.edgesForExtendedLayout = [.bottom]
        
        let webConfiguration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        
        webView.uiDelegate = self
        webView.navigationDelegate = self
        
        webView.allowsBackForwardNavigationGestures = true
        webView.isMultipleTouchEnabled = true
        
        webView.addObserver(self, forKeyPath: estimatedProgressKeyPath, options: .new, context: nil)
        if websiteTitleInNavigationBar {
            webView.addObserver(self, forKeyPath: titleKeyPath, options: .new, context: nil)
        }
        
        //        view = webView
        self.webView = webView
        
        self.webView?.customUserAgent = self.customUserAgent ?? self.userAgent ?? self.originalUserAgent
        
        self.navigationItem.title = self.navigationItem.title ?? self.source?.absoluteString

        if #available(iOS 11.0, *), adjustFontSizeForNavigationBarLargeTitle {
            self.adjustNavigationBarLargeTitleSize()
        }

        if let navigation = self.navigationController {
            let previousBackgroundColor = navigation.navigationBar.backgroundColor ?? .white
            let previousForegroundColor: UIColor = self.getNavigationBarTitleAttribute(attribute: NSAttributedString.Key.foregroundColor) as? UIColor ?? .black
            self.previousNavigationBarState = (navigation.navigationBar.tintColor, previousBackgroundColor, previousForegroundColor, navigation.navigationBar.isHidden)
            self.previousToolbarState = (navigation.toolbar.tintColor, navigation.toolbar.isHidden)
        }
        
        self.setUpProgressView()
        self.setUpConstraints()
        self.addBarButtonItems()
        
        if let s = self.source {
            self.load(source: s)
        } else {
            print("[\(type(of: self))][Error] Invalid url")
        }
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setUpState()
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        rollbackState()
    }
    
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case estimatedProgressKeyPath?:
            guard let estimatedProgress = self.webView?.estimatedProgress else {
                return
            }
            self.progressView?.alpha = 1
            self.progressView?.setProgress(Float(estimatedProgress), animated: true)
            
            if estimatedProgress >= 1.0 {
                UIView.animate(withDuration: 0.3, delay: 0.3, options: .curveEaseOut, animations: {
                    self.progressView?.alpha = 0
                }, completion: {
                    finished in
                    self.progressView?.setProgress(0, animated: false)
                })
            }
        case titleKeyPath?:
            navigationItem.title = webView?.title

            if #available(iOS 11.0, *), adjustFontSizeForNavigationBarLargeTitle {
                self.adjustNavigationBarLargeTitleSize()
            }
            
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

// MARK: - Public Methods
public extension WKWebViewController {
    
    func load(source s: WKWebSource) {
        switch s {
        case .remote(let url):
            self.load(remote: url)
        case .file(let url, access: let access):
            self.load(file: url, access: access)
        case .string(let str, base: let base):
            self.load(string: str, base: base)
        }
    }
    
    func load(remote: URL) {
        webView?.load(createRequest(url: remote))
    }
    
    func load(file: URL, access: URL) {
        webView?.loadFileURL(file, allowingReadAccessTo: access)
    }
    
    func load(string: String, base: URL? = nil) {
        webView?.loadHTMLString(string, baseURL: base)
    }
    
    func goBackToFirstPage() {
        if let firstPageItem = webView?.backForwardList.backList.first {
            webView?.go(to: firstPageItem)
        }
    }
}

// MARK: - Fileprivate Methods
fileprivate extension WKWebViewController {
    var availableCookies: [HTTPCookie]? {
        return cookies?.filter {
            cookie in
            var result = true
            let url = self.source?.remoteURL
            if let host = url?.host, !cookie.domain.hasSuffix(host) {
                result = false
            }
            if cookie.isSecure && url?.scheme != "https" {
                result = false
            }
            
            return result
        }
    }
    func createRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        
        // Set up headers
        if let headers = headers {
            for (field, value) in headers {
                request.addValue(value, forHTTPHeaderField: field)
            }
        }
        
        // Set up Cookies
        if let cookies = availableCookies, let value = HTTPCookie.requestHeaderFields(with: cookies)[cookieKey] {
            request.addValue(value, forHTTPHeaderField: cookieKey)
        }
        
        return request
    }
    
    func setUpProgressView() {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.trackTintColor = UIColor(white: 1, alpha: 0)
        self.progressView = progressView
        //        updateProgressViewFrame()
    }
    
    func setUpConstraints() {
        if let progressView = self.progressView, let web = self.webView {
            self.view.translates(subViews: progressView, web)
            self.view.layout(
                0,
                |progressView| ~ 2,
                0,
                |web|,
                0
            )
        }
    }
    
    func addBarButtonItems() {
        func barButtonItem(_ type: BarButtonItemType) -> UIBarButtonItem? {
            switch type {
            case .back:
                return backBarButtonItem
            case .forward:
                return forwardBarButtonItem
            case .reload:
                return reloadBarButtonItem
            case .stop:
                return stopBarButtonItem
            case .activity:
                return activityBarButtonItem
            case .done:
                return doneBarButtonItem
            case .flexibleSpace:
                return flexibleSpaceBarButtonItem
            case .custom(let icon, let title, let action):
                let item: BlockBarButtonItem
                if let icon = icon {
                    item = BlockBarButtonItem(image: icon, style: .plain, target: self, action: #selector(customDidClick(sender:)))
                } else {
                    item = BlockBarButtonItem(title: title, style: .plain, target: self, action: #selector(customDidClick(sender:)))
                }
                item.block = action
                return item
            }
        }
        
        if presentingViewController != nil {
            switch doneBarButtonItemPosition {
            case .left:
                if !leftNavigaionBarItemTypes.contains(where: { type in
                    switch type {
                    case .done:
                        return true
                    default:
                        return false
                    }
                }) {
                    leftNavigaionBarItemTypes.insert(.done, at: 0)
                }
            case .right:
                if !rightNavigaionBarItemTypes.contains(where: { type in
                    switch type {
                    case .done:
                        return true
                    default:
                        return false
                    }
                }) {
                    rightNavigaionBarItemTypes.insert(.done, at: 0)
                }
            case .none:
                break
            }
        }
        
        navigationItem.leftBarButtonItems = leftNavigaionBarItemTypes.map {
            barButtonItemType in
            if let barButtonItem = barButtonItem(barButtonItemType) {
                return barButtonItem
            }
            return UIBarButtonItem()
        }
        
        navigationItem.rightBarButtonItems = rightNavigaionBarItemTypes.map {
            barButtonItemType in
            if let barButtonItem = barButtonItem(barButtonItemType) {
                return barButtonItem
            }
            return UIBarButtonItem()
        }
        
        if toolbarItemTypes.count > 0 {
            for index in 0..<toolbarItemTypes.count - 1 {
                toolbarItemTypes.insert(.flexibleSpace, at: 2 * index + 1)
            }
        }
        
        setToolbarItems(toolbarItemTypes.map {
            barButtonItemType -> UIBarButtonItem in
            if let barButtonItem = barButtonItem(barButtonItemType) {
                return barButtonItem
            }
            return UIBarButtonItem()
        }, animated: true)
    }
    
    func updateBarButtonItems() {
        backBarButtonItem.isEnabled = webView?.canGoBack ?? false
        forwardBarButtonItem.isEnabled = webView?.canGoForward ?? false
        
        let updateReloadBarButtonItem: (UIBarButtonItem, Bool) -> UIBarButtonItem = {
            [unowned self] barButtonItem, isLoading in
            switch barButtonItem {
            case self.reloadBarButtonItem:
                fallthrough
            case self.stopBarButtonItem:
                return isLoading ? self.stopBarButtonItem : self.reloadBarButtonItem
            default:
                break
            }
            return barButtonItem
        }
        
        let isLoading = webView?.isLoading ?? false
        toolbarItems = toolbarItems?.map {
            barButtonItem -> UIBarButtonItem in
            return updateReloadBarButtonItem(barButtonItem, isLoading)
        }
        
        navigationItem.leftBarButtonItems = navigationItem.leftBarButtonItems?.map {
            barButtonItem -> UIBarButtonItem in
            return updateReloadBarButtonItem(barButtonItem, isLoading)
        }
        
        navigationItem.rightBarButtonItems = navigationItem.rightBarButtonItems?.map {
            barButtonItem -> UIBarButtonItem in
            return updateReloadBarButtonItem(barButtonItem, isLoading)
        }
    }
    
    func setUpState() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.setToolbarHidden(toolbarItemTypes.count == 0, animated: true)
        
        if let tintColor = tintColor {
            progressView?.progressTintColor = tintColor
            navigationController?.navigationBar.tintColor = tintColor
            navigationController?.toolbar.tintColor = tintColor
        }

        if let navBackgroundColor = self.navigationBarBackgroundColor {
            navigationController?.navigationBar.backgroundColor = navBackgroundColor
        }

        if let navForegroundColor = self.navigationBarForegroundColor {
            self.setNavigationBarTitleAttributes(attributes: [NSAttributedString.Key.foregroundColor : navForegroundColor])
        }
    }
    
    func rollbackState() {
        progressView?.progress = 0

        navigationController?.navigationBar.backgroundColor = previousNavigationBarState.backgroundColor
        self.setNavigationBarTitleAttributes(attributes: [NSAttributedString.Key.foregroundColor : previousNavigationBarState.foregroundColor])

        navigationController?.navigationBar.tintColor = previousNavigationBarState.tintColor
        navigationController?.toolbar.tintColor = previousToolbarState.tintColor
        
        navigationController?.setToolbarHidden(previousToolbarState.hidden, animated: true)
        navigationController?.setNavigationBarHidden(previousNavigationBarState.hidden, animated: true)
    }

    func setNavigationBarTitleAttributes(attributes: [NSAttributedString.Key : Any]) {
        guard let navController = self.navigationController else {
            return
        }

        if #available(iOS 11.0, *), let prefersLargeTitles = self.navigationController?.navigationBar.prefersLargeTitles, prefersLargeTitles {
            if navController.navigationBar.largeTitleTextAttributes == nil {
                navController.navigationBar.largeTitleTextAttributes = [NSAttributedString.Key : Any]()
            }
            attributes.forEach {
                navController.navigationBar.largeTitleTextAttributes?[$0.key] = $0.value
            }
        } else {
            if navController.navigationBar.titleTextAttributes == nil {
                navController.navigationBar.titleTextAttributes = [NSAttributedString.Key : Any]()
            }

            attributes.forEach {
                navController.navigationBar.titleTextAttributes?[$0.key] = $0.value
            }
        }
    }

    func getNavigationBarTitleAttribute(attribute: NSAttributedString.Key) -> Any? {

        guard let navController = self.navigationController else {
            return nil
        }

        if #available(iOS 11.0, *), let prefersLargeTitles = self.navigationController?.navigationBar.prefersLargeTitles, prefersLargeTitles {
            return navController.navigationBar.largeTitleTextAttributes?[attribute]
        } else {
            return navController.navigationBar.titleTextAttributes?[attribute]
        }
    }
    
    func checkRequestCookies(_ request: URLRequest, cookies: [HTTPCookie]) -> Bool {
        if cookies.count <= 0 {
            return true
        }
        guard let headerFields = request.allHTTPHeaderFields, let cookieString = headerFields[cookieKey] else {
            return false
        }
        
        let requestCookies = cookieString.components(separatedBy: ";").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "=", maxSplits: 1).map(String.init)
        }
        
        var valid = false
        for cookie in cookies {
            valid = requestCookies.filter {
                $0[0] == cookie.name && $0[1] == cookie.value
                }.count > 0
            if !valid {
                break
            }
        }
        return valid
    }
    
    func openURLWithApp(_ url: URL) -> Bool {
        let application = UIApplication.shared
        if application.canOpenURL(url) {
            return application.openURL(url)
        }
        
        return false
    }
    
    func handleURLWithApp(_ url: URL, targetFrame: WKFrameInfo?) -> Bool {
        let hosts = UrlsHandledByApp.hosts
        let schemes = UrlsHandledByApp.schemes
        let blank = UrlsHandledByApp.blank
        
        var tryToOpenURLWithApp = false
        if let host = url.host, hosts.contains(host) {
            tryToOpenURLWithApp = true
        }
        if let scheme = url.scheme, schemes.contains(scheme) {
            tryToOpenURLWithApp = true
        }
        if blank && targetFrame == nil {
            tryToOpenURLWithApp = true
        }
        
        return tryToOpenURLWithApp ? openURLWithApp(url) : false
    }
    
    @objc func backDidClick(sender: AnyObject) {
        webView?.goBack()
    }
    
    @objc func forwardDidClick(sender: AnyObject) {
        webView?.goForward()
    }
    
    @objc func reloadDidClick(sender: AnyObject) {
        webView?.stopLoading()
        if webView?.url != nil {
            webView?.reload()
        } else if let s = self.source {
            self.load(source: s)
        }
    }
    
    @objc func stopDidClick(sender: AnyObject) {
        webView?.stopLoading()
    }
    
    @objc func activityDidClick(sender: UIBarButtonItem) {
        guard let s = self.source else {
            return
        }
        
        let items: [Any]
        switch s {
        case .remote(let u):
            items = [u]
        case .file(let u, access: _):
            items = [u]
        case .string(let str, base: _):
            items = [str]
        }
        
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityViewController.popoverPresentationController?.barButtonItem = sender
        present(activityViewController, animated: true, completion: nil)
    }
    
    @objc func doneDidClick(sender: AnyObject) {
        var canDismiss = true
        if let url = self.source?.url {
            canDismiss = delegate?.webViewController?(self, canDismiss: url) ?? true
        }
        if canDismiss {
            dismiss(animated: true, completion: nil)
        }
    }
    
    @objc func customDidClick(sender: BlockBarButtonItem) {
        sender.block?(self)
    }

    @objc func adjustNavigationBarLargeTitleSize() {

        guard #available(iOS 11.0, *) else { return }

        let prefersLargeTitle = self.navigationController?.navigationBar.prefersLargeTitles ?? false
        guard prefersLargeTitle, let title = self.navigationItem.title else { return }

        let maxWidth = UIScreen.main.bounds.size.width - 60
        var fontSize = UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
        var width = title.size(withAttributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontSize)]).width

        while width > maxWidth {
            fontSize -= 1
            width = title.size(withAttributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontSize)]).width
        }

        self.navigationController?.navigationBar.largeTitleTextAttributes?[NSAttributedString.Key.font] = UIFont.boldSystemFont(ofSize: fontSize)
    }
}

// MARK: - WKUIDelegate
extension WKWebViewController: WKUIDelegate {
    
}

// MARK: - WKNavigationDelegate
extension WKWebViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        updateBarButtonItems()
        self.progressView?.progress = 0
        if let u = webView.url {
            self.url = u
            delegate?.webViewController?(self, didStart: u)
        }
    }
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateBarButtonItems()
        self.progressView?.progress = 0
        if let url = webView.url {
            self.url = url
            delegate?.webViewController?(self, didFinish: url)
        }
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        updateBarButtonItems()
        self.progressView?.progress = 0
        if let url = webView.url {
            self.url = url
            delegate?.webViewController?(self, didFail: url, withError: error)
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateBarButtonItems()
        self.progressView?.progress = 0
        if let url = webView.url {
            self.url = url
            delegate?.webViewController?(self, didFail: url, withError: error)
        }
    }
    
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let bypassedSSLHosts = bypassedSSLHosts, bypassedSSLHosts.contains(challenge.protectionSpace.host) {
            let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        var actionPolicy: WKNavigationActionPolicy = .allow
        defer {
            decisionHandler(actionPolicy)
        }
        guard let u = navigationAction.request.url else {
            print("Cannot handle empty URLs")
            return
        }
        
        if !self.allowsFileURL && u.isFileURL {
            print("Cannot handle file URLs")
            return
        }
        
        if handleURLWithApp(u, targetFrame: navigationAction.targetFrame) {
            actionPolicy = .cancel
            return
        }
        
        if u.host == self.source?.url?.host, let cookies = availableCookies, !checkRequestCookies(navigationAction.request, cookies: cookies) {
            self.load(remote: u)
            actionPolicy = .cancel
            return
        }
        
        if let navigationType = NavigationType(rawValue: navigationAction.navigationType.rawValue), let result = delegate?.webViewController?(self, decidePolicy: u, navigationType: navigationType) {
            actionPolicy = result ? .allow : .cancel
        }
    }
}

class BlockBarButtonItem: UIBarButtonItem {
    
    var block: ((WKWebViewController) -> Void)?
}
