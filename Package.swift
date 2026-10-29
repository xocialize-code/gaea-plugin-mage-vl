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
            ?? .package(url: "https://github.com/xocialize/gaea-plugin-kit.git", from: "0.3.0"),
        .package(url: "https://github.com/xocialize/mlx-engine-swift.git", from: "0.72.0"),
        // The version pixel-agency-image-engine v0.9.1 resolved, so a reply here can match its reply there.
        .package(url: "https://github.com/xocialize/mage-vl-swift.git", exact: "0.4.0"),
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
