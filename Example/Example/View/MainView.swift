//
//  MainView.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//

import SwiftUI
import Foundation

struct MainView: View {
    
    @ObservedObject var viewModel: MainViewModel
    @State private var showingAlert = !UserDefaults.standard.bool(forKey: "ShownAlert")
    
    var body: some View {
        ZStack {
            Color.mbBackground.ignoresSafeArea()
            VStack {
                ButtonsView(viewModel: viewModel)
                SDKDataView(viewModel: viewModel)
            }
        }.onAppear {
            viewModel.setupData()
            let alertShown = UserDefaults.standard.bool(forKey: "ShownAlert")
            if !alertShown {
                UserDefaults.standard.set(true, forKey: "ShownAlert")
            }
        }
        .alert("In-App can only be shown once per session", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        }
    }
}

#Preview {
    MainView(viewModel: MainViewModel())
}
