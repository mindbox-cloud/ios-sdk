//
//  SDKDataView.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//

import SwiftUI

struct TitleDescrptionView: View {
    var title: String
    var message: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.system(size: 9))
                    .padding(.bottom, 2)
                    .lineLimit(1)
                    .foregroundStyle(.mbText)
                Text(message)
                    .font(.system(size: 13))
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc.fill")
                        }
                    }
                    .lineLimit(1)
                    .foregroundStyle(.mbText)
            }
            Spacer()
        }
    }
}

struct SDKDataView: View {
    
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .frame(width: 350)
                .frame(height: 190)
                .foregroundColor(.mbView)
            VStack {
                HStack {
                    Text("Data from SDK:")
                        .foregroundStyle(.mbText)
                        .padding(.leading, -1)
                        .padding(.bottom, 5)
                    Spacer()
                }
                TitleDescrptionView(title: "SDK version", message: viewModel.SDKVersion)
                Divider()
                TitleDescrptionView(title: "APNS token", message: viewModel.APNSToken)
                Divider()
                TitleDescrptionView(title: "Device UUID", message: viewModel.deviceUUID)
            }
            .frame(width: 310)
        }
    }
}

struct SDKDataView_Preview: PreviewProvider {
    static var previews: some View {
        SDKDataView(viewModel: MainViewModel())
    }
}
