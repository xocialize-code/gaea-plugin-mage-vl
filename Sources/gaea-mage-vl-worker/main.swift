import GaeaPluginKit
import MageVLPlugin

// The plugin's worker: MageVLPlugin's definition over GPP (GaeaPluginKit). `--manifest <path>` writes manifest.json.
await GaeaPluginMain.run(mageVLPlugin)
