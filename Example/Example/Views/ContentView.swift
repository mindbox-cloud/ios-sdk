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
    let url: URL = URL(string: "https://personalization-test-site-staging.mindbox.ru/")!

    var body: some View {
        VStack {
            let _ = print(#function)
            WebView(url: url, viewModel: webViewModel)
                .overlay(loadingOverlay)

            if let errorMessage = webViewModel.errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }

            Button("Print in console Cookies and LocalStorage") {
                webViewModel.viewCookiesAndLocalStorage()
                print("LOL")
            }.padding()
        }
    }

    @ViewBuilder
        private var loadingOverlay: some View {
            if webViewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                    ProgressView("Loading...")
                }
            }
        }

}

//struct MainView: View {
//    
//    var viewModel: MainViewModel
//    @State private var showingAlert = !UserDefaults.standard.bool(forKey: "ShownAlert")
//    
//    var body: some View {
//        NavigationStack {
//            ZStack {
//                Color.mbBackground.ignoresSafeArea()
//                VStack(spacing: 32) {
//                    ButtonsView(viewModel: viewModel)
//                    SDKDataView(viewModel: viewModel)
//                    ZStack {
//                        RoundedRectangle(cornerRadius: 20)
//                            .frame(maxWidth: 350)
//                            .frame(maxHeight: 110)
//                            .foregroundColor(.mbView)
//                        NavigationLink("Open Notification Center") {
//                            NotificationCenterView(viewModel: NotificationCenterViewModel())
//                                .modelContainer(SwiftDataManager.shared.container)
//                        }
//                        .frame(maxWidth: 250)
//                        .frame(maxHeight: 50)
//                        .background(Color.mbGreen)
//                        .cornerRadius(16)
//                        .tint(.white)
//                    }
//                }
//            }.onAppear {
//                viewModel.setupData()
//                let alertShown = UserDefaults.standard.bool(forKey: "ShownAlert")
//                if !alertShown {
//                    UserDefaults.standard.set(true, forKey: "ShownAlert")
//                }
//            }
//            .alert("In-App can only be shown once per session", isPresented: $showingAlert) {
//                Button("OK", role: .cancel) {}
//            }
//        }
//    }
//}
//
//#Preview {
//    MainView(viewModel: MainViewModel())
//}

#Preview {
    ContentView(webViewModel: ViewModel())
}
