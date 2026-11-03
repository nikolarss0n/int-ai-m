"""Builds and runs a visual QA driver for the interview window (question burst + code panel).

The driver is compiled from the real sources listed in build.sh, with DriverEntry.swift spliced in
place of the app's own @main. It drives the real InterviewMasterDelegate with canned data, so it
needs no network, audio, or API keys, and it never touches ~/Documents/InterviewMaster.

    python3 Scripts/focus-ui-qa/build-driver.py [output-dir]

Snapshots (PNG, a text dump of geometry and visible labels, a `.style.txt` manifest of every view's
styles, a `.colors.json` of every text and glyph with the fills behind it, a `.type.json` of how
every string is set and whether it fits, and a `.layout.json` of every box with what a scroll view
clips) are written to output-dir, which defaults to .codex-loop/focus-ui-qa/shots. `colors.py
<output-dir>` audits contrast, `type.py <output-dir>` audits typography, `layout.py <output-dir>`
audits layout, `density.py <output-dir>` audits information density (repeated status words, the
question list against the answer, dead and empty space) `loading.py <output-dir>` audits the loading
states (placeholders, status words, layout shift, Reduce Motion) and `feedback.py <output-dir>` audits what the
window says (capsule truth, errors, confirmations, undo, failed answers).

Environment knobs, passed through to the driver: QA_WINDOW=WxH sets the window size (default
1040x680; the smallest supported is 760x500), QA_WIDEN=0|1 turns "code panel widens the window" off or
on (default on), QA_APPEARANCE=aqua (whole system light) or aqua-window (only the window light) tests the dark
pin, QA_REDUCE_MOTION=1 runs the window as it is with Reduce Motion on, and QA_OUT is the output
directory (the first argument sets it). Check layout at 1040x680, 760x500 with QA_WIDEN=0,
1600x1000 and 760x900.
"""
from pathlib import Path
import os
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
work = root / ".codex-loop/focus-ui-qa"
work.mkdir(parents=True, exist_ok=True)
out_dir = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else work / "shots"

build_sh = (root / "build.sh").read_text()
sources = [line.strip().rstrip("\\").strip() for line in build_sh.splitlines() if line.strip().endswith(".swift \\")]
assert "interview_master.swift" in sources, "build.sh source list changed shape"

spliced = (root / "interview_master.swift").read_text()
spliced = spliced[:spliced.rfind("@available(macOS 14.0, *)\n@main")]
spliced += (Path(__file__).resolve().parent / "DriverEntry.swift").read_text()
spliced_path = work / "interview_master.swift"
spliced_path.write_text(spliced)
sources = [str(spliced_path) if source == "interview_master.swift" else source for source in sources]

binary = work / "focus-ui-qa-driver"
compile_cmd = ["swiftc", "-target", "arm64-apple-macosx14.0", "-o", str(binary)] + sources + [
    "-framework", "Cocoa", "-framework", "Carbon", "-framework", "ScreenCaptureKit",
    "-framework", "AVFoundation", "-framework", "Speech", "-framework", "CoreML", "-framework", "PDFKit",
]
print(f"compiling {len(sources)} sources")
if subprocess.call(compile_cmd, cwd=root) != 0:
    sys.exit(1)

out_dir.mkdir(parents=True, exist_ok=True)
for stale in out_dir.glob("*"):
    stale.unlink()
print(f"running driver, snapshots in {out_dir}")
result = subprocess.call([str(binary)], cwd=root, env={**os.environ, "QA_OUT": str(out_dir)},
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
print("driver exit", result)
sys.exit(result)
