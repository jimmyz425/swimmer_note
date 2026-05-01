import SwiftUI

// MARK: - Swipe to Delete Row

/// Swipe left to delete an item
struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0

    private let deleteThreshold: CGFloat = -100

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background
            Color.red
                .frame(width: max(-offset, 0))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Delete icon
            if offset < -20 {
                Image(systemName: "trash")
                    .foregroundStyle(.white)
                    .padding(.trailing, 16)
            }

            // Content
            content
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(PoolTheme.light.opacity(0.08))
                )
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if value.translation.width < deleteThreshold {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    offset = -300
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onDelete()
                                }
                            } else {
                                withAnimation(.spring()) {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Swipe to Toggle Complete Row

/// Swipe right to toggle completion status (complete/uncomplete)
/// Disabled when session is not assigned to a date
struct SwipeToToggleCompleteRow<Content: View>: View {
    let isAssigned: Bool
    let isCompleted: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0

    private let actionThreshold: CGFloat = 80

    var body: some View {
        ZStack {
            // Action background (swipe right)
            // Green for "complete", Orange for "uncomplete"
            if offset > 20 && isAssigned {
                (isCompleted ? Color.orange : Color.green)
                    .frame(width: max(offset, 0))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                HStack {
                    Image(systemName: isCompleted ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                }
                .padding(.leading, 16)
                .frame(width: max(offset, 0))
            }

            // Content
            content
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow swipe right if assigned
                            if isAssigned {
                                offset = max(0, value.translation.width)
                            }
                        }
                        .onEnded { value in
                            guard isAssigned else {
                                offset = 0
                                return
                            }

                            // Swipe right → Toggle completion
                            if value.translation.width > actionThreshold {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    offset = 200
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onToggle()
                                    withAnimation(.spring()) {
                                        offset = 0
                                    }
                                }
                            }
                            // Reset if not past threshold
                            else {
                                withAnimation(.spring()) {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}