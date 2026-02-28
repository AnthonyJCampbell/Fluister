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

    static let fast = ModelSource(
        filename: "ggml-base.bin",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!,
        sha256: "", // TODO: Pin SHA256 after first successful download — see docs/RELEASE.md
        sizeDescription: "~142 MB"
    )

    static let balanced = ModelSource(
        filename: "ggml-small.bin",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!,
        sha256: "", // TODO: Pin SHA256 after first successful download — see docs/RELEASE.md
        sizeDescription: "~466 MB"
    )

    static func source(for profile: ModelProfile) -> ModelSource {
        switch profile {
        case .fast: return fast
        case .balanced: return balanced
        }
    }
}
