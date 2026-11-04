"""Grant the test app permission and open Android's notification shade at handoff."""

from pathlib import Path
import subprocess
import sys
import time


def main():
    device = sys.argv[1] if len(sys.argv) > 1 else "emulator-5554"
    root = Path("build/notification_audit")
    root.mkdir(parents=True, exist_ok=True)

    def adb(*args):
        return subprocess.check_output(["adb", "-s", device, *args], timeout=15)

    log = subprocess.Popen(
        ["adb", "-s", device, "logcat", "-T", "1", "-v", "raw", "-s", "flutter:I"],
        stdout=subprocess.PIPE, text=True, encoding="utf-8", errors="replace",
    )
    try:
        for line in log.stdout:
            if "NOTIFICATION_AUDIT_PERMISSION" in line:
                adb("shell", "pm", "grant", "chat.liuxin.mission_book", "android.permission.POST_NOTIFICATIONS")
            if "NOTIFICATION_AUDIT_READY" in line:
                adb("shell", "cmd", "statusbar", "expand-notifications")
                time.sleep(1)
                (root / "shade-before.png").write_bytes(adb("exec-out", "screencap", "-p"))
                print("Notification shade opened. Click Clear all within 60 seconds.", flush=True)
                return
        raise RuntimeError("Device log ended before test handoff")
    finally:
        log.terminate()
        log.wait(timeout=5)


if __name__ == "__main__":
    main()
