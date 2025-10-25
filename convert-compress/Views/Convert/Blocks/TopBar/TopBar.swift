import SwiftUI

struct TopBar: View {
    @State private var purchaseManager = PurchaseManager.shared
    @ObservedObject private var usageTracker = UsageTracker.shared
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack {
            Spacer()
            // Titlebar content on trailing side
            HStack(spacing: 8) {
                Text(isHovered ? "Converted: \(usageTracker.totalImageConversions)" : "\(usageTracker.totalImageConversions)")
                    .font(.system(.caption, design: .monospaced))
                    // .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.18), value: isHovered)
                    .frame(minWidth: 130, alignment: .trailing)
                    .onHover { hovering in
                        isHovered = hovering
                    }
                
                Menu {
                    if !purchaseManager.isProUnlocked {
                        Button {
                            PaywallCoordinator.shared.presentManually()
                        } label: {
                            Label("Buy Lifetime", systemImage: "sparkle") 
                        }
                        Divider()
                    }
                    
                    Button {
                        sendFeedbackEmail()
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                    
                    Button {
                        RatingService.requestReview()
                    } label: {
                        Label("Rate App", systemImage: "star")
                    }
                    
                    Link(destination: URL(string: "https://convert-compress.com")!) {
                        Label("Website", systemImage: "globe")
                    }
                    
                    ShareLink(item: URL(string: "https://convert-compress.com")!) {
                        Label("Share App", systemImage: "square.and.arrow.up")
                    }
                    
                    Link(destination: URL(string: "https://github.com/rpgraffi/convert-compress")!) {
                        Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .medium))
                        // .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                // .foregroundColor(.secondary)
            }
        }
        .foregroundColor(.secondary)
        .frame(height: 56)
        .padding(.trailing, 16)
        .padding(.leading, 70) // Traffic Lights Padding
    }
    
    private func sendFeedbackEmail() {
        let recipient = "me@raffi.studio"
        let subject = "Feedback"
        
        if let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "mailto:\(recipient)?subject=\(encodedSubject)") {
            NSWorkspace.shared.open(url)
        }
    }
}

