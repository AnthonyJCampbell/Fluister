import Foundation

/// Pinned model source definitions.
/// All models use quantized (q5) variants for faster inference and smaller downloads.
/// Full-precision models are ~2-3x larger with marginal quality improvement.
struct ModelSource {
    let filename: String
    let url: URL
    let sha256: String
    let sizeDescription: String
}

enum ModelSources {
    // NOTE: These URLs point to the ggerganov/whisper.cpp HuggingFace repository.
    // Using q5 quantized models: ~50-65% smaller, ~20-40% faster, negligible quality loss.

    static let tiny = ModelSource(
        filename: "ggml-tiny-q5_1.bin",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-q5_1.bin")!,
        sha256: "",
        sizeDescription: "32 MB"
    )

    static let base = ModelSource(
        filename: "ggml-base-q5_1.bin",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin")!,
        sha256: "",
        sizeDescription: "60 MB"
    )

    static let small = ModelSource(
        filename: "ggml-small-q5_1.bin",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin")!,
        sha256: "",
        sizeDescription: "190 MB"
    )

    static let medium = ModelSource(
        filename: "ggml-medium-q5_0.bin",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q5_0.bin")!,
        sha256: "",
        sizeDescription: "539 MB"
    )

    static let large = ModelSource(
        filename: "ggml-large-v3-q5_0.bin",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-q5_0.bin")!,
        sha256: "",
        sizeDescription: "1.1 GB"
    )

    static let turbo = ModelSource(
        filename: "ggml-large-v3-turbo-q5_0.bin",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin")!,
        sha256: "",
        sizeDescription: "574 MB"
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
