//
//  NotificationCenterView.swift
//  Example
//
//  Created by Sergei Semko on 6/10/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import SwiftUI
import SwiftData

struct NotificationCenterView: View {
    
    var viewModel: NotificationCenterViewModelProtocol
    
    @State private var showAlert = false
    @State private var alertTitle = String()
    @State private var alertMessage = String()
    
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(items.reversed()) { item in
                    ZStack {
                        Color.clear
                        HStack {
                            NotificationCellView(notification: item.mbPushNotification)
                            Spacer()
                        }
                    }
                    
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.sendOperationNCPushOpen(notification: item.mbPushNotification)
                        if let errorMessage = viewModel.errorMessage {
                            alertMessage = errorMessage
                        } else {
                            alertMessage = "Operation NSPushOpen sent to Mindbox"
                        }
                        showAlert = true
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                }
                .onDelete(perform: deleteItems)
            }
        }
        .onAppear {
            viewModel.sendOperationNCOpen()
        }
        .navigationTitle("Notification Center")
        .navigationBarTitleDisplayMode(.large)
        .alert(
            alertMessage,
            isPresented: $showAlert,
            presenting: viewModel.lastTappedNotification) { notification in
                Text("Unique key: \(notification.uniqueKey ?? "Empty")")
                Button("OK", action: {})
            }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            let originalOffsets = IndexSet(offsets.map { items.count - 1 - $0 })
            for index in originalOffsets {
                let item = items[index]
                if item.mbPushNotification.clickUrl == "https://mindbox.ru/" {
                    return
                } else {
                    modelContext.delete(items[index])
                    
                }
            }
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}

#Preview {
    NotificationCenterView(viewModel: NotificationCenterViewModel())
}
