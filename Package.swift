// swift-tools-version: 6.2
import PackageDescription

// gaea-plugin-mage-vl: Microsoft's Mage-VL 4B (Apache-2.0) on mage-vl-swift, serving MES `image.describe` (Gaea
// AB-T-0377), the model pixel-agency-image-engine v0.9.1 answers image analysis with. One worker executable on
// GaeaPluginKit, packaged as a signed .gaeaplugin by scripts/build-plugin.sh.
//
// mage-vl-inproc is not part of the plugin: it runs the same request in-process through MLXServeEngine, on this
// package's one dependency resolution, as the reference a reply over GPP is compared against.
//
// GAEA_PLUGIN_KIT_PATH points the kit at a local checkout while you work on both.
let kitPath = Context.environment["GAEA_PLUGIN_KIT_PATH"]

let package = Package(
    name: "gaea-plugin-mage-vl",
    platforms: [.macOS(.v26)], // mlx-engine-swift's MLXToolKit requires macOS 26
    dependencies: [
        kitPath.map { .package(path: $0) }
            ?? .package(url: "https://github.com/xocialize-code/gaea-plugin-kit.git", from: "0.14.1"), // 0.14.1 on: the manifest names the engine actually linked (AB-L-0366)
        // mlx-engine-swift 0.82.1, the first on the fleet's mlx-swift 0.33.1.
        .package(url: "https://github.com/xocialize/mlx-engine-swift.git", from: "0.82.1"),
        .package(url: "https://github.com/xocialize/mage-vl-swift.git", exact: "0.4.1"), // its newest (0.4.0 plus the LICENSE file); admits mlx-swift 0.33.x (ml-explore from 0.30.0)
        // The fleet's mlx-swift fork, as mlx-engine-swift 0.82.1 takes it: 0.33.1 is upstream 0.33.0 with the vendored
        // MLX's head-dim-split SDPA routes off, which abort or give wrong attention on M5 (AB-D-0264, AB-R-1009). Named
        // at the root so no dependency's ml-explore URL wins and builds the unpatched one.
        .package(url: "https://github.com/xocialize/mlx-swift", from: "0.33.1"),
    ],
    targets: [
        .target(
            name: "MageVLPlugin",
            dependencies: [
                .product(name: "GaeaPluginKit", package: "gaea-plugin-kit"),
                .product(name: "MLXToolKit", package: "mlx-engine-swift"),
                .product(name: "MLXMageVL", package: "mage-vl-swift"),
            ]
        ),
        .executableTarget(
            name: "gaea-mage-vl-worker",
            dependencies: [
                "MageVLPlugin",
                .product(name: "GaeaPluginKit", package: "gaea-plugin-kit"),
            ]
        ),
        .executableTarget(
            name: "mage-vl-inproc",
            dependencies: [
                "MageVLPlugin",
                .product(name: "MLXMageVL", package: "mage-vl-swift"),
                .product(name: "MLXServeCore", package: "mlx-engine-swift"),
                .product(name: "MLXToolKit", package: "mlx-engine-swift"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
