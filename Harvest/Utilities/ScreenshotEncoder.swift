import UIKit

/// Turns a picked image into something cheap enough to send to a vision model.
///
/// Phone screenshots are far larger than the model needs, and vision cost
/// scales with resolution, so everything is downscaled before encoding. The
/// result is a `data:` URL — the image is never written to disk or uploaded to
/// storage.
enum ScreenshotEncoder {
    /// Longest side, in pixels, after downscaling. Matches `MAX_DIMENSION` in
    /// ScreenshotEncoder.kt: chat text stays legible well below a full-res
    /// screenshot, and both platforms must send comparable detail.
    static let maxDimension: CGFloat = 1400
    static let jpegQuality: CGFloat = 0.7
    /// Refuse anything still this large once encoded; the request would be
    /// rejected upstream anyway, and failing here gives a better message.
    static let maxEncodedBytes = 4 * 1024 * 1024

    enum EncodingError: LocalizedError {
        case couldNotEncode
        case tooLarge

        var errorDescription: String? {
            switch self {
            case .couldNotEncode:
                return "That image couldn't be read. Try a different screenshot."
            case .tooLarge:
                return "That image is too large. Try a smaller screenshot."
            }
        }
    }

    /// Longest-edge target for a send of `imageCount` images. Text in a phone
    /// screenshot stays legible at 900px, which is what makes the top of the
    /// ladder affordable. Mirrors `targetDimension` in ScreenshotEncoder.kt —
    /// a count of zero or less falls in the first rung, as it does there.
    static func targetDimension(imageCount: Int) -> CGFloat {
        if imageCount <= 2 { return maxDimension }
        if imageCount <= 5 { return 1100 }
        return 900
    }

    /// A `data:image/jpeg;base64,...` URL suitable for an `image_url` part.
    static func dataURL(from image: UIImage, target: CGFloat = maxDimension) throws -> String {
        let scaled = downscaled(image, limit: target)
        guard let jpeg = scaled.jpegData(compressionQuality: jpegQuality) else {
            throw EncodingError.couldNotEncode
        }
        guard jpeg.count <= maxEncodedBytes else {
            throw EncodingError.tooLarge
        }
        return "data:image/jpeg;base64," + jpeg.base64EncodedString()
    }

    /// Aspect-preserving downscale so the longest side is at most
    /// `maxDimension`. Images already smaller are returned untouched.
    static func downscaled(_ image: UIImage, limit: CGFloat = maxDimension) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > limit, longest > 0 else { return image }

        let ratio = limit / longest
        let target = CGSize(width: (size.width * ratio).rounded(),
                            height: (size.height * ratio).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1   // target is already in pixels
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
