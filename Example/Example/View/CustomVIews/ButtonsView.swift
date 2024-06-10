//
//  ButtonsView.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//

import SwiftUI

struct ButtonsViewline: View {
    
    var label: String
    var action: () -> ()
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.mbText)
            Spacer()
            Button("Show In-App") {
                action()
            }
            .frame(width: 120)
            .frame(height: 30)
            .background(Color.mbGreen)
            .cornerRadius(10)
            .tint(.white)
        }
    }
}

struct ButtonsView: View {
    
    var viewModel: MainViewModel
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .frame(width: 350)
                .frame(height: 110)
                .foregroundColor(.mbView)
            VStack {
                ButtonsViewline(label: "Async operation") {
                    viewModel.showInAppWithExecuteAsyncOperation()
                }
                Divider()
                ButtonsViewline(label: "Sync operation") {
                    viewModel.showInAppWithExecuteSyncOperation()
                }
            }
            .frame(width: 310)
        }
    }
}
