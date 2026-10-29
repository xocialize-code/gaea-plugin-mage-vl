import Foundation
import GaeaPluginKit
import GaeaProtocol
import MLXMageVL
import MLXToolKit

// gaea-plugin-mage-vl: Microsoft's Mage-VL 4B (Apache-2.0) answering questions about an image, served as MES
// `image.describe` (Gaea AB-T-0377). Registered as pixel-agency-image-engine v0.9.1 registers it (mlx-image-runtime's
// GenerativeCatalog.mageVL: int8, mage-vl-swift 0.4.0), and a call mapped the way its RequestMapping maps one.
//
// Gaea's image normalizer asks the question (its caption, alt text and tags prompt) and parses the reply; the worker
// only runs it. The image comes as input `image`, the question as the text input `question`, and the reply goes back as
// the value `text`, which Gaea reads as the model's text.

public let describeOperation = "image.describe"

/// The question when the call carries none: mlx-image-runtime's `RequestMapping.defaultAnalysisQuestion`.
public let defaultQuestion = "Describe this image in one or two sentences."

/// The configuration v0.9.1 serves: int8 (greedy output byte-identical to bf16 and the PyTorch reference, 5.37 GB
/// floor against bf16's 9.51 GB).
public let configuration = MageVLConfiguration(quant: .int8)

/// The engine request for a question about an image, as v0.9.1 builds it: no mode, no package keys.
public func request(image: Image, question: String?) -> ImageAnalysisRequest {
    ImageAnalysisRequest(image: image, prompt: question ?? defaultQuestion, mode: nil, metaData: [:])
}

/// The lane is named after its quant (GPP-1 §4.7). Mage-VL's quant is the package's own `MageVLQuant`, so its
/// configuration isn't `QuantConfigured` and the engine's resolution names no quant: it starts from the largest footprint
/// (bf16) and takes int8's resident bytes and lane reserve from the configuration's hints (`FootprintConfigured`). The
/// name comes from the configuration, which is what the hints describe.
public let laneID = configuration.quant.rawValue

/// The licence the offer states, from the package's own manifest (its weights' licence).
func license(_ manifest: PackageManifest) -> JSONValue {
    let weights = manifest.license.weightLicense
    var license: [String: JSONValue] = ["spdx": .string(weights.identifier), "commercial_use": .bool(weights.isPermissive)]
    if let notice = weights.requiredDisplayText { license["notice"] = .string(notice) }
    return .object(license)
}

/// Describe: `image` and the text input `question`; the reply is the value `text`.
let describe = EngineOperation(describeOperation) { job in
    EngineCall(request(image: try job.image("image"), question: try job.text("question")))
}

let notes = "Image understanding: captions, alt text, tags and visual questions. int8, about 5.4 GB resident; it "
    + "resizes any input to its own pixel cap."

public let mageVLPlugin = GaeaPluginDefinition(
    id: "com.xocialize.gaea.mage-vl",
    version: "0.1.0",
    minGaea: "0.6.0",
    team: "CFZS6RXUCP",
    repo: "https://github.com/xocialize/gaea-plugin-mage-vl",
    title: "Mage-VL",
    summary: "Microsoft's Mage-VL 4B (Apache-2.0) on mage-vl-swift: answers questions about an image, int8. Gaea's image "
        + "normalizer asks it for captions, alt text and tags (image.describe).",
    license: "Apache-2.0",
    executable: "gaea-mage-vl-worker",
    models: [
        .engine(MageVLPackage.self, id: "mage-vl", title: "Mage-VL",
                lanes: [LaneDefinition(id: laneID, default: true, configuration: configuration)], operations: [describe]),
    ],
    offers: [
        PluginManifest.Offer(
            operation: describeOperation, profile: "image",
            model: ["id": "mage-vl", "title": "Mage-VL", "license": license(MageVLPackage.manifest), "memory_class": "medium",
                    "speed_class": "fast", "quality_tiers": ["draft", "standard", "best"], "notes": .string(notes)],
            // The package resizes inputs to its own cap, so the size limit is only a sanity bound.
            limits: PluginManifest.Limits(maxPixels: 100_000_000, sizeMultiple: 1, maxImages: 1)),
    ])
