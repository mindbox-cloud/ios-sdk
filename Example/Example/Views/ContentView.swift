//
//  ContentView.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import SwiftUI
import WebKit

struct ContentView: View {

    let webViewModel: ViewModel

    private let url = URL(string: "https://your-website.com/")

    var body: some View {
        VStack {
            WebView(url: url, viewModel: webViewModel)

            Button("Print in console Cookies and LocalStorage") {
                guard let webView = WebView.currentWebView else {
                    print("WebView is not initialized yet")
                    return
                }
                webViewModel.viewCookiesAndLocalStorage(with: webView)
            }.padding()
        }
    }
}

#Preview {
    ContentView(webViewModel: ViewModel())
}
