//
//  NotificationCenterView.swift
//  Example
//
//  Created by Sergei Semko on 6/10/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import SwiftUI

struct NotificationCenterView: View {
    
    @State var showAlert = false
    var viewModel: NotificationCenterViewModelProtocol
    
    var body: some View {
        NavigationStack {
            List(viewModel.notifications, id: \.uniqueKey) { notification in
                NotificationCellView(notification: notification)
                    .onTapGesture {
                        viewModel.sendOperationNCPushOpen(notification: notification)
                        showAlert = true
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
            }
        }
        .onAppear {
            viewModel.sendOperationNCOpen()
        }
        .navigationTitle("Notification Details")
        .navigationBarTitleDisplayMode(.large)
        .alert(
            "Operation NSPushOpen sent to Mindbox",
            isPresented: $showAlert,
            presenting: viewModel.lastTappedNotification) { notification in
                Text("Unique key: \(notification.uniqueKey ?? "Empty")")
                Text("Title: \(notification.aps?.alert?.title ?? "Empty")")
                Text("Body: \(notification.aps?.alert?.body ?? "Empty")")
                Text("URL: \(notification.clickUrl ?? "Empty")")
                Button("OK", action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                })
                
            }
    }
}

#Preview {
    NotificationCenterView(viewModel: NotificationCenterViewModel())
}
