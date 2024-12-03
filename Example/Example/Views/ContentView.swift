//
//  ContentView.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import SwiftUI

struct ContentView: View {

    var webViewModel: ViewModel
    let url = URL(string: "https://your-website.com/")

    var body: some View {
        VStack {
            WebView(url: url, viewModel: webViewModel)

            Button("Print in console Cookies and LocalStorage") {
                webViewModel.viewCookiesAndLocalStorage()
            }.padding()
        }
    }
}

#Preview {
    ContentView(webViewModel: ViewModel())
}
