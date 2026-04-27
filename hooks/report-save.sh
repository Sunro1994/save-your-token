#!/bin/bash
# report-save 훅 — 일별 토큰 사용량 자동 저장
# 동작: 하루 1회 ~/.claude/token-diet-reports/YYYY-MM-DD.json 저장
# 용도: /token-diet 실행 시 트렌드 비교에 활용

REPORTS_DIR="$HOME/.claude/token-diet-reports"
TODAY=$(date +%Y-%m-%d)
REPORT_FILE="$REPORTS_DIR/$TODAY.json"

# ── python3 확인 ──────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  exit 0
fi

# ── 오늘 리포트가 이미 있으면 건너뜀 ─────────────────────────
if [ -f "$REPORT_FILE" ]; then
  exit 0
fi

mkdir -p "$REPORTS_DIR"

PROJECTS_DIR="$HOME/.claude/projects"

# ── 세션 데이터 파싱 및 저장 ──────────────────────────────────
python3 - << PYEOF
import json, os, sys
from pathlib import Path
from datetime import date
from collections import defaultdict

CATEGORIES = {
    "코드 생성":    ["만들어", "작성해", "생성해", "구현해", "짜줘", "create", "write", "generate", "implement", "build"],
    "설명/질문":    ["설명해", "알려줘", "뭐야", "어떻게", "왜", "무엇", "explain", "what", "why", "how", "tell me"],
    "수정/리팩토링": ["수정해", "고쳐", "개선해", "리팩토링", "바꿔", "fix", "refactor", "improve", "update", "optimize"],
    "파일/탐색":    ["읽어", "찾아", "확인해", "보여줘", "read", "find", "search", "show", "check"],
    "분석/리뷰":    ["분석해", "리뷰해", "검토해", "평가해", "analyze", "review", "evaluate"],
}

def classify(text):
    t = text.lower()
    for cat, kws in CATEGORIES.items():
        if any(k in t for k in kws):
            return cat
    return "기타"

def parse_session(filepath):
    by_uuid = {}
    with open(filepath, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                obj = json.loads(line)
                uid = obj.get("uuid")
                if uid and uid not in by_uuid:
                    by_uuid[uid] = obj
            except: continue

    def get_text(r):
        msg = r.get("message") or {}
        content = msg.get("content", "")
        if isinstance(content, list):
            return " ".join(c.get("text","") for c in content
                           if isinstance(c, dict) and c.get("type")=="text").strip()
        return str(content).strip()

    pairs = []
    for r in by_uuid.values():
        if r.get("type") != "user": continue
        uid   = r.get("uuid")
        text  = get_text(r)
        if not text: continue
        asst  = next((x for x in by_uuid.values()
                      if x.get("type")=="assistant" and x.get("parentUuid")==uid), None)
        if not asst: continue
        usage = (asst.get("message") or {}).get("usage") or {}
        inp   = (usage.get("input_tokens") or 0) + (usage.get("cache_read_input_tokens") or 0)
        out   = usage.get("output_tokens") or 0
        if inp + out == 0: continue
        ts    = r.get("timestamp", "")
        pairs.append({"text": text[:80], "cat": classify(text),
                      "input": inp, "output": out, "total": inp + out, "timestamp": ts})
    return pairs

projects_dir = Path(os.environ.get("HOME", "")) / ".claude" / "projects"
if not projects_dir.exists():
    sys.exit(0)

# 오늘 날짜 기준 세션 파일만 수집 (최근 24시간)
import time
cutoff = time.time() - 86400
all_pairs = []
for f in projects_dir.rglob("*.jsonl"):
    try:
        if f.stat().st_mtime < cutoff: continue
        all_pairs.extend(parse_session(f))
    except: continue

if not all_pairs:
    sys.exit(0)

# 집계
total_tokens = sum(p["total"] for p in all_pairs)
total_cmds   = len(all_pairs)
avg_per_cmd  = total_tokens // total_cmds if total_cmds else 0

by_cat = defaultdict(lambda: {"count": 0, "tokens": 0})
for p in all_pairs:
    by_cat[p["cat"]]["count"]  += 1
    by_cat[p["cat"]]["tokens"] += p["total"]

top3 = sorted(all_pairs, key=lambda x: x["total"], reverse=True)[:3]

report = {
    "date":         str(date.today()),
    "total_tokens": total_tokens,
    "total_cmds":   total_cmds,
    "avg_per_cmd":  avg_per_cmd,
    "categories":   dict(by_cat),
    "top3": [{"text": p["text"], "cat": p["cat"], "total": p["total"]} for p in top3],
}

report_path = Path(os.environ.get("HOME","")) / ".claude" / "token-diet-reports" / f"{date.today()}.json"
report_path.parent.mkdir(parents=True, exist_ok=True)
with open(report_path, "w", encoding="utf-8") as f:
    json.dump(report, f, ensure_ascii=False, indent=2)

print(f"리포트 저장: {report_path}", file=sys.stderr)
PYEOF

exit 0
