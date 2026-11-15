import subprocess
import sys
from pathlib import Path

folder = Path(__file__).resolve().parent
with (folder / "bridge.log").open("a", encoding="utf-8") as log:
    subprocess.Popen(
        [sys.executable, "-u", str(folder / "bridge.py")],
        cwd=folder,
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=subprocess.STDOUT,
        creationflags=subprocess.CREATE_NO_WINDOW,
    )
