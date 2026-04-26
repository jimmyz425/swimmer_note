import SwiftUI

enum PoolTheme {
    static let surface = Color(red: 0.91, green: 0.98, blue: 1.0)
    static let light = Color(red: 0.74, green: 0.91, blue: 0.96)
    static let mid = Color(red: 0.18, green: 0.58, blue: 0.72)
    static let deep = Color(red: 0.04, green: 0.22, blue: 0.33)
    static let gold = Color(red: 1.0, green: 0.71, blue: 0.16)
}

struct PoolCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PoolTheme.light.opacity(0.45), lineWidth: 1)
            }
    }
}

extension View {
    func poolCard() -> some View {
        modifier(PoolCard())
    }
}
