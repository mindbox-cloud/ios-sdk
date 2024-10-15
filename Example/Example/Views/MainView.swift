//
//  MainView.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import SwiftUI

struct MainView: View {
    
    var viewModel: MainViewModel
    @State private var showingAlert = !UserDefaults.standard.bool(forKey: "ShownAlert")
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.mbBackground.ignoresSafeArea()
                VStack(spacing: 32) {
                    ButtonsView(viewModel: viewModel)
                    SDKDataView(viewModel: viewModel)
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .frame(maxWidth: 350)
                            .frame(maxHeight: 110)
                            .foregroundColor(.mbView)
                        NavigationLink("Open Notification Center") {
                            NotificationCenterView(viewModel: NotificationCenterViewModel())
                                .modelContainer(SwiftDataManager.shared.container)
                        }
                        .frame(maxWidth: 250)
                        .frame(maxHeight: 50)
                        .background(Color.mbGreen)
                        .cornerRadius(16)
                        .tint(.white)
                    }
                    
                    Text(viewModel.updatedSdkVersion ?? viewModel.SDKVersion)
                    
                    Button(action: {
                        viewModel.getUpdatedSDKVersion()
                    }) {
                        Text("Press me")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: 250)
                            .background(Color.blue)
                            .cornerRadius(16)
                            .shadow(radius: 5)
                    }
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
}

#Preview {
    MainView(viewModel: MainViewModel())
}
