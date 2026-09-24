import os
import shutil
import subprocess
import time
from kittens.tui.handler import result_handler

def main(args):
    pass

@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    """
    Saves clipboard image to a temporary file via pngpaste and
    pastes the generated file path into Kitty's active window.
    """
    candidate_paths = [
        "/opt/local/bin/pngpaste",
        "/opt/homebrew/bin/pngpaste",
        "/usr/local/bin/pngpaste",
    ]
    pngpaste_bin = None
    for path in candidate_paths:
        if os.path.isfile(path) and os.access(path, os.X_OK):
            pngpaste_bin = path
            break

    if not pngpaste_bin:
        pngpaste_bin = shutil.which("pngpaste")

    if not pngpaste_bin:
        return

    tmp_file = f"/tmp/clip_{int(time.time())}.png"
    res = subprocess.run([pngpaste_bin, tmp_file], capture_output=True)
    if res.returncode == 0 and os.path.exists(tmp_file):
        w = boss.window_id_map.get(target_window_id)
        if w is not None:
            w.paste_text(f"{tmp_file} ")
        else:
            boss.paste_to_active_window(f"{tmp_file} ")
