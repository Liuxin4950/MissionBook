import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
cache = Path.home() / '.gradle/caches/modules-2/files-2.1'


def jar(package):
    return str(next((cache / package).rglob('*.jar')))


stdlib = jar('org.jetbrains.kotlin/kotlin-stdlib/2.3.21')
compiler = os.pathsep.join([
    jar('org.jetbrains.kotlin/kotlin-compiler-embeddable/2.3.21'),
    stdlib,
    jar('org.jetbrains.kotlin/kotlin-script-runtime/2.3.21'),
    jar('org.jetbrains.kotlin/kotlin-reflect/2.2.21'),
    jar('org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm/1.8.0'),
    jar('org.jetbrains/annotations/13.0'),
])
with tempfile.TemporaryDirectory(prefix='missionbook-long-capture-') as output:
    subprocess.run([
        'java', '-cp', compiler, 'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler',
        '-no-stdlib', '-no-reflect', '-classpath', stdlib, '-d', output,
        str(root / 'android/app/src/main/kotlin/chat/liuxin/mission_book/LongCaptureMatcher.kt'),
        str(root / 'tool/long_capture_matcher_test.kt'),
    ], check=True)
    subprocess.run([
        'java', '-cp', os.pathsep.join([output, stdlib]),
        'chat.liuxin.mission_book.Long_capture_matcher_testKt',
    ], check=True)
