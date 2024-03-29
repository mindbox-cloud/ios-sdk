//
//  ButtonsView.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//

import SwiftUI

struct ButtonsView: View {
    
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .frame(width: 350)
                .frame(height: 110)
                .foregroundColor(.mbLightGray)
            VStack {
                HStack {
                    Text("Async operation")
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Show In-App") {
                        viewModel.showInAppWithExecuteAsyncOperation()
                    }
                    .frame(width: 120)
                    .frame(height: 30)
                    .background(Color.mbGreen)
                    .cornerRadius(10)
                    .tint(.white)
                }
                Divider()
                HStack {
                    Text("Sync operation")
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Show In-App") {
                        viewModel.showInAppWithExecuteSyncOperation()
                    }
                    .frame(width: 120)
                    .frame(height: 30)
                    .background(Color.mbGreen)
                    .cornerRadius(10)
                    .tint(.white)
                }
            }
            .frame(width: 310)
            
        }
    }
}
