import SwiftUI

struct EmptyScreen: View {
    let title: LocalizedStringKey
    let icon: String
    let detail: LocalizedStringKey

    var body: some View {
        VStack(spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}
