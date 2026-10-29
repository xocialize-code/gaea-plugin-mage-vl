#!/bin/zsh
# Photos described over GPP on the signed bundle (gaea-plugin-check: launch under the launch requirement, configure,
# prepare, run, shutdown) and in-process (mage-vl-inproc: MLXServeEngine, Mage-VL registered as the plugin registers it,
# the same request, on this package's dependency resolution), with the default question and with the image normalizer's
# describe question (pixel-agency-normalizer's Describe.prompt, English), and the two texts compared. Mage-VL decodes
# greedily, so they must be identical.
#
#   scripts/golden.sh <out-dir>     (after scripts/build-plugin.sh and `swift build -c release --product mage-vl-inproc`)
#
# Environment: DIV2K, a DIV2K validation photo (default: mlxengine-image's corpus, 0801.png).
set -uo pipefail
ROOT=${0:A:h:h}
cd $ROOT
OUT=${1:?out dir}; mkdir -p $OUT
B=$ROOT/dist/mage-vl.gaeaplugin
MODELS=${CHECK_MODELS_ROOT:-$HOME/Library/Application Support/MLXEngine/Models}
BIN=$(xcrun swift build -c release --show-bin-path)
CHECK=$BIN/gaea-plugin-check; INPROC=$BIN/mage-vl-inproc
QUESTION=$ROOT/scripts/fixtures/describe-question.txt
DIV2K=${DIV2K:-$ROOT/../mlxengine-image/corpus/sr-bench/DIV2K_valid_HR/0801.png}
LOG=$OUT/golden.log; : > $LOG
pass=0; fail=0
say() { print -r -- "$*" | tee -a $LOG }

# name, photo, question (default | describe)
golden() {
  local name=$1 photo=$2 question=$3
  local inputs=(--input "image=$photo") mine=()
  [[ $question == describe ]] && { inputs+=(--input "question=$QUESTION"); mine=(--question-file $QUESTION) }
  $CHECK $B --operation image.describe --model mage-vl --lane int8 --params '{}' $inputs \
    --models-root "$MODELS" --budget 64000000000 --timeout 600 --session $OUT/$name.gpp > $OUT/$name-gpp.log 2>&1
  $INPROC --image $photo $mine --models-root "$MODELS" > $OUT/$name-inproc.json 2>> $LOG
  python3 - "$OUT/$name.gpp" "$OUT/$name-inproc.json" "$name" >> $LOG <<'EOF'
import hashlib, json, sys
gpp, inproc, name = sys.argv[1:]
result = next(json.loads(l[2:]) for l in open(gpp) if l.startswith("W ") and '"type":"result"' in l)
text = next(o["value"] for o in result["outputs"] if o["name"] == "text")
mine = json.load(open(inproc))
print(f"{name}: GPP in {result['seconds']:.2f} s (cold worker); in-process run {mine['warm_s']:.2f} s, "
      f"prepare {mine['prepare_s']:.2f} s; sha256 {hashlib.sha256(text.encode()).hexdigest()[:16]}…")
print("  GPP:        " + text[:240].replace("\n", " "))
assert text.strip(), "the reply is empty"
assert text == mine["text"], "the texts differ; in-process: " + mine["text"][:240].replace("\n", " ")
EOF
  if (( $? == 0 )); then pass=$((pass+1)); say "PASS  $name: the same text over GPP and in-process"
  else fail=$((fail+1)); say "FAIL  $name: $(tail -1 $LOG)"; fi
}

say "# Mage-VL golden check $(date -u +%FT%TZ): $(python3 -c "import json; m=json.load(open('$B/Contents/Resources/manifest.json')); print(m['id'], m['version'])")"
for photo in fox:$ROOT/scripts/fixtures/fox-256.png face:$ROOT/scripts/fixtures/face-512.png div2k-0801:$DIV2K; do
  [[ -f ${photo#*:} ]] || { fail=$((fail+1)); say "FAIL  ${photo%%:*}: no photo at ${photo#*:}"; continue }
  golden ${photo%%:*}-default ${photo#*:} default
  golden ${photo%%:*}-describe ${photo#*:} describe
done
say "== $pass passed, $fail failed"
exit $(( fail > 0 ))
