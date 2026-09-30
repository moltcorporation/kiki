import PhotosUI
import SwiftUI

/// The runner's profile photo, stored on this device. Sign in with Apple
/// doesn't share a photo, so the default is their initial on a dark circle;
/// tapping it (no visible badge) lets them pick one from their library.
struct ProfileAvatar: View {
    let userID: String?
    let name: String?
    var size: CGFloat = 88

    @State private var image: UIImage?
    @State private var selection: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            // No badge: adding a photo is a quiet nice-to-have; tapping the
            // avatar opens the picker.
            avatar
        }
        .buttonStyle(.haptic)
        .accessibilityLabel(image == nil ? "Add a profile photo" : "Change profile photo")
        .contextMenu {
            if image != nil {
                Button("Remove photo", systemImage: "trash", role: .destructive) {
                    if let userID { AvatarStore.remove(userID: userID) }
                    image = nil
                }
            }
        }
        .task(id: userID) {
            image = userID.flatMap { AvatarStore.load(userID: $0) }
        }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let picked = UIImage(data: data) else { return }
                let resized = picked.squareThumbnail(side: 512)
                if let userID { AvatarStore.save(resized, userID: userID) }
                image = resized
                selection = nil
                Haptics.success()
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(.circle)
        } else {
            ZStack {
                Circle().fill(Color.ink)
                if let initial = name?.trimmingCharacters(in: .whitespaces).first {
                    Text(String(initial).uppercased())
                        .font(.system(size: size * 0.42, weight: .black).italic())
                        .foregroundStyle(.paper)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.paper)
                }
            }
            .frame(width: size, height: size)
        }
    }
}

/// Profile photos saved in Application Support, one per account.
enum AvatarStore {
    private static func url(userID: String) -> URL {
        let folder = URL.applicationSupportDirectory.appending(path: "avatars", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "\(userID).jpg")
    }

    static func load(userID: String) -> UIImage? {
        UIImage(contentsOfFile: url(userID: userID).path())
    }

    static func save(_ image: UIImage, userID: String) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: url(userID: userID), options: .atomic)
    }

    static func remove(userID: String) {
        try? FileManager.default.removeItem(at: url(userID: userID))
    }
}

private extension UIImage {
    /// A centered square crop scaled to `side` points.
    func squareThumbnail(side: CGFloat) -> UIImage {
        let edge = min(size.width, size.height)
        let origin = CGPoint(x: (size.width - edge) / 2, y: (size.height - edge) / 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            draw(in: CGRect(
                x: -origin.x * side / edge,
                y: -origin.y * side / edge,
                width: size.width * side / edge,
                height: size.height * side / edge
            ))
        }
    }
}
