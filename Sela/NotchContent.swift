import SwiftUI

struct NotchContent: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sela")
                    .font(.headline)

                Text("DynamicNotchKit aktif")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(width: 300)
    }
}
