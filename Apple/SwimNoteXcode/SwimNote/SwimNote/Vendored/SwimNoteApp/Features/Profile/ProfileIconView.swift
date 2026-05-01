import SwiftUI

struct ProfileIconView: View {
    let profile: UserProfile
    var size: CGFloat = 36

    var body: some View {
        switch profile.profileIconType {
        case .letter:
            letterIcon
        case .image:
            imageIcon
        case .icon:
            symbolIcon
        }
    }

    private var letterIcon: some View {
        Circle()
            .fill(PoolTheme.deep)
            .frame(width: size, height: size)
            .overlay {
                Text(profile.initials)
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            }
    }

    @ViewBuilder
    private var imageIcon: some View {
        if let data = profile.profileImageData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            letterIcon
        }
    }

    private var symbolIcon: some View {
        let iconName = profile.profileIconName ?? "person.circle.fill"
        return Image(systemName: iconName)
            .font(.system(size: size * 0.6))
            .foregroundStyle(PoolTheme.deep)
            .frame(width: size, height: size)
    }
}

struct ProfileIconPicker: View {
    @Binding var iconType: ProfileIconType
    @Binding var imageData: Data?
    @Binding var iconName: String?
    let name: String
    @State private var showingImagePicker = false
    @State private var showingIconPicker = false

    private let availableIcons: [(String, String)] = [
        ("person.circle.fill", "Person"),
        ("figure.pool.swim", "Swimmer"),
        ("figure.walk", "Walker"),
        ("star.fill", "Star"),
        ("trophy.fill", "Trophy"),
        ("flame.fill", "Flame"),
        ("heart.fill", "Heart"),
        ("bolt.fill", "Bolt"),
        ("leaf.fill", "Leaf"),
        ("sun.max.fill", "Sun")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // Letter option
                iconOption(.letter) {
                    Circle()
                        .fill(iconType == .letter ? PoolTheme.deep : PoolTheme.mid)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Text(String(name.prefix(1).uppercased()))
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                }

                // Image option
                iconOption(.image) {
                    if let data = imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                            .overlay {
                                if iconType == .image {
                                    Circle().stroke(PoolTheme.deep, lineWidth: 2)
                                }
                            }
                    } else {
                        Circle()
                            .fill(iconType == .image ? PoolTheme.deep : PoolTheme.mid)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: "camera.fill")
                                    .foregroundStyle(.white)
                            }
                    }
                }

                // Icon option
                iconOption(.icon) {
                    let symbol = iconName ?? "person.circle.fill"
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundStyle(iconType == .icon ? PoolTheme.deep : PoolTheme.mid)
                        .frame(width: 44, height: 44)
                }
            }

            if iconType == .image {
                Button {
                    showingImagePicker = true
                } label: {
                    Label("Choose Photo", systemImage: "photo.on.rectangle")
                }
            }

            if iconType == .icon {
                Text("Choose an icon:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 12)], spacing: 12) {
                    ForEach(availableIcons, id: \.0) { symbol, label in
                        Button {
                            iconName = symbol
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: symbol)
                                    .font(.title2)
                                Text(label)
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(iconName == symbol ? PoolTheme.deep : PoolTheme.surface)
                            .foregroundStyle(iconName == symbol ? .white : PoolTheme.mid)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(imageData: $imageData)
        }
    }

    private func iconOption(_ type: ProfileIconType, @ViewBuilder content: () -> some View) -> some View {
        Button {
            iconType = type
        } label: {
            content()
                .overlay {
                    if iconType == type {
                        Circle()
                            .stroke(PoolTheme.deep, lineWidth: 2)
                            .frame(width: 48, height: 48)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(imageData: $imageData, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let imageData: Binding<Data?>
        let dismiss: DismissAction

        init(imageData: Binding<Data?>, dismiss: DismissAction) {
            self.imageData = imageData
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                let resized = image.resized(to: CGSize(width: 200, height: 200))
                imageData.wrappedValue = resized?.pngData()
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized
    }
}

// MARK: - Previews

#Preview("Profile Icon - Letter") {
    ProfileIconView(
        profile: UserProfile(
            id: "preview",
            name: "Alex",
            birthday: "1995-06-15",
            sex: .male,
            skillLevel: .intermediate,
            weeklySessionTarget: 3,
            preferredStrokes: [.freestyle],
            profileIconType: .letter,
            personalBests: PersonalBests(freestyle50m: 32.5),
            trainingGoals: [],
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        ),
        size: 60
    )
}

#Preview("Profile Icon - Symbol") {
    ProfileIconView(
        profile: UserProfile(
            id: "preview",
            name: "Alex",
            birthday: "1995-06-15",
            sex: .male,
            skillLevel: .intermediate,
            weeklySessionTarget: 3,
            preferredStrokes: [.freestyle],
            profileIconType: .icon,
            profileIconName: "figure.pool.swim",
            personalBests: PersonalBests(freestyle50m: 32.5),
            trainingGoals: [],
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        ),
        size: 60
    )
}

#Preview("Profile Icon Picker") {
    ProfileIconPicker(
        iconType: Binding.constant(.letter),
        imageData: Binding.constant(nil),
        iconName: Binding.constant(nil),
        name: "Alex"
    )
    .padding()
    .background(PoolTheme.surface)
}

#Preview("Profile Icon Picker - Icon Mode") {
    ProfileIconPicker(
        iconType: Binding.constant(.icon),
        imageData: Binding.constant(nil),
        iconName: Binding.constant("figure.pool.swim"),
        name: "Alex"
    )
    .padding()
    .background(PoolTheme.surface)
}

#Preview("Profile Icons - Various Sizes") {
    HStack(spacing: 16) {
        ProfileIconView(
            profile: UserProfile(
                id: "p1", name: "A", birthday: "1995-01-01", sex: .male, skillLevel: .beginner,
                weeklySessionTarget: 2, preferredStrokes: [], profileIconType: .letter,
                personalBests: .empty(), trainingGoals: [],
                createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z"
            ),
            size: 24
        )
        ProfileIconView(
            profile: UserProfile(
                id: "p2", name: "B", birthday: "1995-01-01", sex: .female, skillLevel: .intermediate,
                weeklySessionTarget: 3, preferredStrokes: [], profileIconType: .letter,
                personalBests: .empty(), trainingGoals: [],
                createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z"
            ),
            size: 40
        )
        ProfileIconView(
            profile: UserProfile(
                id: "p3", name: "C", birthday: "1995-01-01", sex: .male, skillLevel: .elite,
                weeklySessionTarget: 5, preferredStrokes: [], profileIconType: .letter,
                personalBests: .empty(), trainingGoals: [],
                createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z"
            ),
            size: 80
        )
    }
    .padding()
    .background(PoolTheme.surface)
}