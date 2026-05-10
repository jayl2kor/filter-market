import DesignSystem
import SwiftUI
import UIKit

struct EditableProfileAvatar: View {
    let profile: EditableProfile
    let size: FMAvatar.Size
    var fallback: String?

    init(profile: EditableProfile, size: FMAvatar.Size = .md, fallback: String? = nil) {
        self.profile = profile
        self.size = size
        self.fallback = fallback
    }

    var body: some View {
        if let image = profile.localAvatarImage {
            FMAvatar(image: Image(uiImage: image), size: size)
        } else {
            FMAvatar(url: profile.avatarURL, size: size, fallback: fallback ?? profile.initials)
        }
    }
}

private extension EditableProfile {
    var localAvatarImage: UIImage? {
        guard let avatarImageData else { return nil }
        return UIImage(data: avatarImageData)
    }
}
