"""Run native capture geometry regressions with the cached Kotlin compiler.

This checks selection and edge geometry on the JVM. It does not test Android
WindowManager, touch delivery or MediaProjection on a device.
"""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
CACHE = Path(os.environ.get("GRADLE_USER_HOME", Path.home() / ".gradle")) / "caches/modules-2/files-2.1"


def cached_jar(group, artifact, version=None):
    directory = CACHE / group / artifact
    if version:
        directory /= version
    matches = sorted(directory.rglob("*.jar"))
    if not matches:
        raise SystemExit(f"Missing cached Kotlin dependency: {directory}. Run Android Gradle compilation first.")
    return str(matches[-1])


def main():
    standard_library = cached_jar("org.jetbrains.kotlin", "kotlin-stdlib", "2.3.21")
    compiler_path = os.pathsep.join([
        cached_jar("org.jetbrains.kotlin", "kotlin-compiler-embeddable", "2.3.21"),
        standard_library,
        cached_jar("org.jetbrains.kotlin", "kotlin-script-runtime", "2.3.21"),
        cached_jar("org.jetbrains.kotlin", "kotlin-reflect"),
        cached_jar("org.jetbrains.kotlinx", "kotlinx-coroutines-core-jvm"),
        cached_jar("org.jetbrains", "annotations"),
    ])
    source = ROOT / "android/app/src/main/kotlin/chat/liuxin/mission_book"
    checks = ROOT / "android/app/src/test/kotlin/chat/liuxin/mission_book/CaptureInteractionChecks.kt"
    with tempfile.TemporaryDirectory(prefix="missionbook-capture-checks-") as output:
        subprocess.run([
            "java", "-cp", compiler_path, "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler",
            "-no-stdlib", "-no-reflect", "-classpath", standard_library, "-d", output,
            str(source / "CaptureSelection.kt"), str(source / "OverlayEdgeGeometry.kt"), str(checks),
        ], check=True)
        subprocess.run([
            "java", "-cp", os.pathsep.join([output, standard_library]),
            "chat.liuxin.mission_book.CaptureInteractionChecksKt",
        ], check=True)


if __name__ == "__main__":
    main()
