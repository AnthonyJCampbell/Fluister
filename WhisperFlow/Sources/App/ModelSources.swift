import Foundation

/// Pinned model source definitions.
/// Update URLs and SHA256 hashes here when model sources change.
struct ModelSource {
    let filename: String
    let url: URL
    let sha256: String
    let sizeDescription: String
}

enum ModelSources {
    // NOTE: These URLs point to the ggerganov/whisper.cpp HuggingFace repository.
    // If URLs become stale, update them here. The app will show a message if download fails.

    static let tiny = ModelSource(
        filename: "ggml-tiny.bin",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin")!,
        sha256: "",
        sizeDescription: "75 MB"
    )

    static let base = ModelSource(
        filename: "ggml-base.bin",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!,
        sha256: "",
        sizeDescription: "142 MB"
    )

    static let small = ModelSource(
        filename: "ggml-small.bin",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!,
        sha256: "",
        sizeDescription: "466 MB"
    )

    static let medium = ModelSource(
        filename: "ggml-medium.bin",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin")!,
        sha256: "",
        sizeDescription: "1.5 GB"
    )

    static let large = ModelSource(
        filename: "ggml-large-v3.bin",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin")!,
        sha256: "",
        sizeDescription: "3.1 GB"
    )

    static let turbo = ModelSource(
        filename: "ggml-large-v3-turbo.bin",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!,
        sha256: "",
        sizeDescription: "1.6 GB"
    )

    static func source(for profile: ModelProfile) -> ModelSource {
        switch profile {
        case .tiny:   return tiny
        case .base:   return base
        case .small:  return small
        case .medium: return medium
        case .large:  return large
        case .turbo:  return turbo
        }
    }
}
