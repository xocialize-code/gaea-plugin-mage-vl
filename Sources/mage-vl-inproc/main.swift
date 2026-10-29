import Foundation
import MageVLPlugin
import MLXMageVL
import MLXServeCore
import MLXToolKit

// The in-process reference for image.describe: Mage-VL registered as the plugin registers it, the request the worker
// builds for the same call, run through MLXServeEngine in this process. Prints one JSON line: the text, load and run
// timings, and the measured footprint (phys_footprint once loaded, after the runs, and its lifetime peak). `--repeat N`
// runs the request N times on the loaded model, so the warm time is the last. Not part of the plugin bundle.
//
//   mage-vl-inproc --image <png|jpg> [--question <text> | --question-file <path>] [--repeat 2] [--models-root <dir>]

var args = Array(CommandLine.arguments.dropFirst())
func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    defer { args.removeSubrange(i...(i + 1)) }
    return args[i + 1]
}
func seconds(since start: ContinuousClock.Instant) -> Double {
    let d = ContinuousClock.now - start
    return Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
}
func usage() -> rusage_info_v4 {
    var info = rusage_info_v4()
    _ = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0) }
    }
    return info
}
func physFootprint() -> UInt64 { usage().ri_phys_footprint }

let started = ContinuousClock.now
guard let imagePath = option("--image") else {
    FileHandle.standardError.write(Data("usage: mage-vl-inproc --image <png|jpg> [--question <text>] [options]\n".utf8))
    exit(2)
}
// The worker reads the question from a UTF-8 file (Gaea's text input); --question-file reads it the same way.
let question = try option("--question") ?? option("--question-file").map { try String(contentsOfFile: $0, encoding: .utf8) }
let repeats = max(1, Int(option("--repeat") ?? "") ?? 1)
let modelsRoot = URL(fileURLWithPath: option("--models-root")
                     ?? NSHomeDirectory() + "/Library/Application Support/MLXEngine/Models", isDirectory: true)
let image = Image(format: imagePath.lowercased().hasSuffix(".png") ? .png : .jpeg,
                  data: try Data(contentsOf: URL(fileURLWithPath: imagePath)))

let engine = MLXServeEngine(workerBudget: WorkerBudget(ceilingBytes: 64_000_000_000, wiresWeights: false))
await engine.useModelStore(ModelStore(root: modelsRoot))
let package = PackageID("mage-vl")
_ = try await engine.register(MageVLPackage.registration, configuration: configuration, id: package)
var clock = ContinuousClock.now
_ = try await engine.prepare(.imageAnalysis, package: package)
let prepare = seconds(since: clock)
let loaded = physFootprint()

var runs: [Double] = [], text = ""
for _ in 0 ..< repeats {
    clock = ContinuousClock.now
    let response = try await engine.run(request(image: image, question: question), package: package) as! ImageAnalysisResponse
    runs.append(seconds(since: clock))
    text = response.text
}

let out: [String: Any] = ["model": "mage-vl", "lane": laneID, "question": question == nil ? "default" : "given",
                          "text": text, "prepare_s": prepare, "run_s": runs, "warm_s": runs.last!,
                          "cold_s": seconds(since: started), "phys_footprint_loaded": loaded,
                          "phys_footprint": physFootprint(), "peak_phys_footprint": usage().ri_lifetime_max_phys_footprint]
let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
print(String(decoding: data, as: UTF8.self))
