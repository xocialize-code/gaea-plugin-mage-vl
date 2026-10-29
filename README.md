# gaea-plugin-mage-vl

Image understanding for [Gaea](https://github.com/xocialize/gaea): Microsoft's Mage-VL 4B (`microsoft/Mage-VL`,
Apache-2.0) on [mage-vl-swift](https://github.com/xocialize/mage-vl-swift), serving MES `image.describe`. Add it by its
repo URL:

```bash
gaea plugins add https://github.com/xocialize/gaea-plugin-mage-vl
```

## What it does

- **One model, `mage-vl`**, in one lane: `int8` (`mlx-community/Mage-VL-8bit`, about 5.4 GB resident), as
  pixel-agency-image-engine v0.9.1 serves it. Its greedy output is byte-identical to bf16 and to the PyTorch reference.
- **One offer, `image.describe`** (Image profile). It takes `image` and the text input `question`, and answers the
  value `text`. With no question, it asks "Describe this image in one or two sentences.", as v0.9.1 does.
- **Any size in.** Mage-VL resizes the picture to its own pixel cap, so the offer's limit (100 MP) is only a sanity
  bound.

In Gaea, the image normalizer asks for a caption, alt text and tags as JSON (in the caller's language), and parses the
reply into the profile's `description`.

## Build and check locally

```bash
scripts/build-plugin.sh
```

```bash
scripts/check-plugin.sh
```

`check-plugin.sh` describes a fixture photo over GPP with the image normalizer's question, with every `.build` folder
hidden. A control then shows that the bare worker, outside the bundle, can't find MLX's metallib.

```bash
swift build -c release --product mage-vl-inproc && scripts/golden.sh <out-dir>
```

`golden.sh` describes three photos (two fixtures and a DIV2K validation photo) with the default question and the
normalizer's, over GPP and in-process (`mage-vl-inproc`: MLXServeEngine, the same registration and request), and
compares the texts. `scripts/release.sh` builds, checks, notarizes with the fleet's `mlx-notary` profile and publishes
the GitHub release; see the [demo plugin](https://github.com/xocialize/gaea-plugin-demo) for signing and CI secrets.

## Licence

The plugin is Apache-2.0 (Gaea G-21). Mage-VL's weights and mage-vl-swift's port are Apache-2.0. The fixture photos
come from [gaea-plugin-forge](https://github.com/xocialize/gaea-plugin-forge).
