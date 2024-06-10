//
//  NotificationCellView.swift
//  Example
//
//  Created by Sergei Semko on 6/10/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import SwiftUI
import Mindbox

struct NotificationCellView: View {
    var notification: MBPushNotification
    
    var body: some View {
        HStack(alignment: .center, content: {
            if let imageUrl = notification.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: 64, maxHeight: 64)
                .clipShape(Capsule())
            }
            
            VStack(alignment: .leading, content: {
                Text(notification.aps?.alert?.title ?? "Empty")
                    .font(.headline)
                Text(notification.aps?.alert?.body ?? "Empty")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                
                if let pushLink = notification.clickUrl {
                    Text(pushLink)
                        .font(.footnote)
                        .foregroundStyle(.blue)
                }
            })
        })
    }
}

#Preview {
    NotificationCellView(notification: NotificationCenterViewModel().notifications.first!)
}
