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
    
    var body: some View {
        ZStack {
                Color.mbDarkGray.ignoresSafeArea()
            VStack {
                ButtonsView(viewModel: viewModel)
                SDKDataView(viewModel: viewModel)
            }
        }
    }
}

#Preview {
    MainView(viewModel: MainViewModel())
}
