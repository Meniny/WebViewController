//
//  ViewController.swift
//  Sample
//
//  Created by Meniny on 2018-01-20.
//  Copyright © 2018年 Meniny. All rights reserved.
//

import UIKit
import WebKit
import WKWebViewController

class ViewController: UIViewController {

    let url = URL.init(string: "https://meniny.cn/")!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func presentWeb(_ sender: UIButton) {
        let webViewController = WKWebViewController.init()
        webViewController.source = .remote(url)
        webViewController.bypassedSSLHosts = [url.host!]
        webViewController.userAgent = "WKWebViewController/1.0.0"
        webViewController.websiteTitleInNavigationBar = true
        webViewController.leftNavigaionBarItemTypes = [.reload]
        webViewController.toolbarItemTypes = [.back, .forward, .activity]
        webViewController.navigationBarBackgroundColor = .white
        webViewController.navigationBarForegroundColor = .blue
        webViewController.tintColor = .red
        let navigation = UINavigationController.init(rootViewController: webViewController)
        if #available(iOS 11.0, *) {
            navigation.navigationBar.prefersLargeTitles = true
            webViewController.adjustFontSizeForNavigationBarLargeTitle = true
        }
        
        self.present(navigation, animated: true, completion: nil)
    }
    
    @IBAction func showWeb(_ sender: UIButton) {
        let webViewController = WKWebViewController.init()
        webViewController.source = .remote(url)
        webViewController.headers = ["browser": "in-app browser"]
        webViewController.tintColor = .red
        webViewController.navigationBarBackgroundColor = .white
        webViewController.navigationBarForegroundColor = .blue
        webViewController.cookies = [
            HTTPCookie(properties:
                [HTTPCookiePropertyKey.originURL: url.absoluteString,
                 HTTPCookiePropertyKey.path: "/",
                 HTTPCookiePropertyKey.name: "author",
                 HTTPCookiePropertyKey.value: "Elias Abel"])!,
            HTTPCookie(properties:
                [HTTPCookiePropertyKey.originURL: url.absoluteString,
                 HTTPCookiePropertyKey.path: "/",
                 HTTPCookiePropertyKey.name: "GitHub",
                 HTTPCookiePropertyKey.value: "Meniny"])!]

        if #available(iOS 11.0, *) {
            webViewController.adjustFontSizeForNavigationBarLargeTitle = true
        }

        self.navigationController?.pushViewController(webViewController, animated: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

