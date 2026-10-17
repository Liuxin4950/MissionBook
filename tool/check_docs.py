"""Check documentation links and the shared Mission Book specification contracts.

Run from any directory: python tool/check_docs.py
This is a documentation check, not a substitute for application acceptance tests.
"""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
FILES = sorted(DOCS.rglob("*.md")) + [ROOT / "README.md"]
PHASES = {"NOT_STARTED", "RUNNING", "PAUSED", "EVIDENCE_PENDING", "CLOSED", "CANCELLED"}
POLICIES = {"SELF_REPORT", "OPTIONAL_EVIDENCE", "REQUIRED_EVIDENCE"}
TABLES = {
    "Goal": "goals",
    "GoalNode": "goal_nodes",
    "Mission": "missions",
    "MissionScheduleRevision": "mission_schedule_revisions",
    "ExecutionPlan": "execution_plans",
    "ExecutionEvent": "execution_events",
    "Evidence": "evidence",
    "FailureRecord": "failure_records",
}
LEGACY = re.compile(
    r"\b(?:LifecycleStage|ExecutionState|VerificationState|lifecycleStage|"
    r"executionState|verificationState|closureReason|readyAt|EVALUATION_PENDING|"
    r"EVALUATION_NOT_AVAILABLE|NOT_SUBMITTED|MISSING_DEADLINE|SCHEDULED|READY|"
    r"PROPOSED|CONFIRMED|ENDED)\b"
)
ERRORS: list[str] = []
TEXT = {path: path.read_text(encoding="utf-8-sig") for path in FILES}


def fail(path: Path, message: str, line: int | None = None) -> None:
    where = path.relative_to(ROOT).as_posix()
    ERRORS.append(f"{where}{':' + str(line) if line else ''}: {message}")


def slug(text: str) -> str:
    text = re.sub(r"\[([^]]+)\]\([^)]+\)", r"\1", text).replace("`", "")
    return "".join(
        char for char in text.lower()
        if char in " _-" or unicodedata.category(char)[0] in "LMN"
    ).replace(" ", "-")


def scan(path: Path) -> tuple[str, set[str]]:
    """Blank fenced code for link scanning and validate all JSON examples."""
    output: list[str] = []
    headings: set[str] = set()
    counts: dict[str, int] = {}
    fence: str | None = None
    language = ""
    body: list[str] = []
    start = 0
    for number, line in enumerate(TEXT[path].splitlines(), 1):
        marker = re.match(r"^\s*(`{3,}|~{3,})(.*)$", line)
        if marker:
            token, suffix = marker.groups()
            if fence is None:
                fence, language, body, start = token, suffix.strip(), [], number
            elif token[0] == fence[0] and len(token) >= len(fence) and not suffix.strip():
                if language == "json":
                    try:
                        json.loads("\n".join(body))
                    except json.JSONDecodeError as error:
                        fail(path, f"invalid JSON example: {error.msg}", start + error.lineno)
                fence = None
            else:
                body.append(line)
            output.append("")
            continue
        if fence is not None:
            body.append(line)
            output.append("")
            continue
        output.append(line)
        heading = re.match(r"^#{1,6}\s+(.+?)\s*#*\s*$", line)
        if heading:
            base = slug(heading.group(1))
            count = counts.get(base, 0)
            counts[base] = count + 1
            headings.add(base if not count else f"{base}-{count}")
    if fence is not None:
        fail(path, "unclosed code fence", start)
    return "\n".join(output), headings


SCANNED = {path: scan(path) for path in FILES}
GRAPH: dict[Path, set[Path]] = {path: set() for path in FILES}
link_count = 0
for path, (prose, _) in SCANNED.items():
    for match in re.finditer(r"!?\[[^\]\n]*\]\(([^)\n]+)\)", prose):
        raw = match.group(1).strip()
        target = raw[1:raw.index(">")] if raw.startswith("<") else raw.split(' "', 1)[0]
        parsed = urlsplit(target)
        if parsed.scheme or parsed.netloc:
            continue
        relative = unquote(parsed.path)
        destination = ((path.parent / relative) if relative else path).resolve()
        number = prose.count("\n", 0, match.start()) + 1
        link_count += 1
        if not destination.exists():
            fail(path, f"missing link target: {target}", number)
            continue
        if not destination.is_relative_to(ROOT):
            fail(path, f"local link escapes repository: {target}", number)
            continue
        # Windows resolves paths case-insensitively; verify committed spelling too.
        current = ROOT
        for component in destination.relative_to(ROOT).parts:
            names = {child.name for child in current.iterdir()}
            if component not in names:
                fail(path, f"incorrect path case: {target}", number)
                break
            current /= component
        if destination in GRAPH:
            GRAPH[path].add(destination)
        if parsed.fragment and destination in SCANNED:
            anchor = unquote(parsed.fragment)
            if anchor not in SCANNED[destination][1]:
                fail(path, f"missing heading anchor: {target}", number)

visited: set[Path] = set()
pending = [ROOT / "README.md"]
while pending:
    current = pending.pop()
    if current not in visited:
        visited.add(current)
        pending.extend(GRAPH[current] - visited)
for path in set(FILES) - visited:
    fail(path, "Markdown document is unreachable from root README")

for path, text in TEXT.items():
    # Future proposals may introduce their own vocabulary; current specs may not.
    if path.name == "未来方向.md":
        continue
    for match in LEGACY.finditer(text):
        fail(path, f"retired state/field remains: {match.group()}", text.count("\n", 0, match.start()) + 1)


def table(path: Path, first_heading: str) -> list[list[str]]:
    lines = TEXT[path].splitlines()
    for index, line in enumerate(lines):
        if line.startswith(f"| {first_heading} |"):
            rows: list[list[str]] = []
            for row in lines[index + 2:]:
                if not row.startswith("|"):
                    break
                rows.append([cell.strip() for cell in row.strip("|").split("|")])
            return rows
    fail(path, f"missing table: {first_heading}")
    return []


domain = DOCS / "v1.0" / "领域模型.md"
ui = DOCS / "v1.0" / "界面与交互.md"
data = DOCS / "v1.0" / "数据模型.md"
platform = DOCS / "v1.0" / "数据落地与平台.md"

for path, header in ((domain, "Phase"), (ui, "Phase")):
    phases = [row[0] for row in table(path, header)]
    if len(phases) != len(PHASES) or set(phases) != PHASES:
        fail(path, f"phase table must contain exactly {sorted(PHASES)}")

mapping = {row[0]: row[1] for row in table(platform, "对象")}
if mapping != TABLES:
    fail(platform, "core object/table mapping differs from the eight-object contract")
objects = re.search(r"当前核心对象只有 ([^。]+)。", TEXT[data])
if not objects or set(objects.group(1).split("、")) != set(TABLES):
    fail(data, "persistent object list differs from the core table mapping")

expected_routes = {
    ("NOT_COMPLETED", policy, "不适用"): "CLOSED" for policy in POLICIES
}
expected_routes.update({
    ("COMPLETED", "SELF_REPORT", "不适用"): "CLOSED",
    ("COMPLETED", "OPTIONAL_EVIDENCE", "false"): "CLOSED",
    ("COMPLETED", "OPTIONAL_EVIDENCE", "true"): "EVIDENCE_PENDING",
    ("COMPLETED", "REQUIRED_EVIDENCE", "截止时间未到"): "EVIDENCE_PENDING",
    ("COMPLETED", "REQUIRED_EVIDENCE", "截止时间已到"): "CLOSED",
})
routes: dict[tuple[str, str, str], str] = {}
for result, policy, choice, phase in table(domain, "END 报告"):
    phase_name = phase.split("；", 1)[0]
    for expanded in (POLICIES if policy == "任意" else [policy]):
        key = (result, expanded, choice)
        if key in routes:
            fail(domain, f"duplicate END route: {key}")
        routes[key] = phase_name
if routes != expected_routes:
    fail(domain, "END matrix must cover all eight policy/result/choice/deadline routes")

# Submission, explicit waiver and timeout must all terminate the evidence phase.
material_routes = table(domain, "当前 Phase")
for operation in ("FinalizeEvidenceSubmission", "SkipOptionalEvidence", "ApplyEvidenceDeadline"):
    matching = [row for row in material_routes if row[1] == operation]
    if len(matching) != 1 or "EVIDENCE_PENDING" not in matching[0][0] or "→ CLOSED" not in matching[0][2]:
        fail(domain, f"missing unique material closure route: {operation}")

if ERRORS:
    print("Documentation checks failed:")
    for error in ERRORS:
        print(f"- {error}")
    sys.exit(1)

print(
    f"DOCS_OK: {len(FILES)} Markdown files, {link_count} local links; "
    f"six phases, eight END routes, eight core tables; "
    "anchors, JSON, fences, reachability, and retired vocabulary checked."
)
