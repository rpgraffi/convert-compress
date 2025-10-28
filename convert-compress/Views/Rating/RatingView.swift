import SwiftUI

struct RatingView: View {
    @Bindable private var coordinator = RatingCoordinator.shared
    
    var body: some View {
        let imageCount = UsageTracker.shared.totalImageConversions
        
        ZStack {
            if coordinator.showSecondPrompt {
                SecondRatingPrompt(coordinator: coordinator)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                FirstRatingPrompt(coordinator: coordinator, imageCount: imageCount)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(Theme.Animations.smooth(), value: coordinator.showSecondPrompt)
    }
}

// MARK: - First Prompt

private struct FirstRatingPrompt: View {
    let coordinator: RatingCoordinator
    let imageCount: Int
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("\(imageCount)")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text(String(localized: "RATING_PROMPT_1_TITLE", defaultValue: "Images processed"))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(String(localized: "RATING_PROMPT_1_DESCRIPTION", defaultValue: "How is your experience with \(AppConstants.localizedAppName) so far?"))
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)
            .padding(16)
            
            VStack(spacing: 8) {
                Button(action: { coordinator.userLikesApp() }) {
                    Text(String(localized: "RATING_PROMPT_1_BUTTON_LIKE", defaultValue: "I like it"))
                        .font(.system(size: 18, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(8)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                
                Button(action: { coordinator.dismiss() }) {
                    Text(String(localized: "RATING_PROMPT_1_BUTTON_OKAY", defaultValue: "It's okay"))
                        .font(.system(size: 18, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(8)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }

        }
        .padding(8)
        .frame(width: 340)
    }
}

// MARK: - Second Prompt

private struct SecondRatingPrompt: View {
    let coordinator: RatingCoordinator
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(String(localized: "RATING_PROMPT_2_TITLE", defaultValue: "Glad to hear that!"))
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                
                Text(String(localized: "RATING_PROMPT_2_DESCRIPTION", defaultValue: "If you have a moment, leaving a short review helps me and keeps development moving forward. <3"))
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)
            .padding(16)
            
            VStack(spacing: 8) {
                Button(action: { coordinator.rateApp() }) {
                    Text(String(localized: "RATING_PROMPT_2_BUTTON_RATE", defaultValue: "Rate App"))
                        .font(.system(size: 18, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(8)
                }
                .buttonBorderShape(.capsule)
                .buttonStyle(.borderedProminent)

                Button(action: { coordinator.dismiss(permanently: true) }) {
                    Text(String(localized: "RATING_PROMPT_2_BUTTON_NEVER", defaultValue: "Never show again"))
                        .font(.system(size: 18, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(8)
                }
                .buttonBorderShape(.capsule)
                .buttonStyle(.bordered)
            }
        }
        .padding(8)
        .frame(width: 340)
    }
}

#Preview("First Prompt") {
    FirstRatingPrompt(coordinator: .shared, imageCount: 150)
        .frame(width: 600, height: 400)
        .background(.regularMaterial)
}

#Preview("Second Prompt") {
    SecondRatingPrompt(coordinator: .shared)
        .frame(width: 600, height: 400)
        .background(.regularMaterial)
}

#Preview("Full Flow") {
    RatingView()
        .frame(width: 600, height: 400)
        .background(.regularMaterial)
}

