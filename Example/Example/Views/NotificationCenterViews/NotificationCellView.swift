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
                .clipShape(Circle())
            }
            
            VStack(alignment: .leading, content: {
                Text(notification.aps?.alert?.title ?? "Empty")
                    .font(.headline)
                Text(notification.aps?.alert?.body ?? "Empty")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Text(notification.clickUrl ?? "Empty")
                    .font(.footnote)
                    .foregroundStyle(.blue)
            })
        })
    }
}
