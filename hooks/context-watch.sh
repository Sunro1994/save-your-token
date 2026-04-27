#!/bin/bash
# context-watch 훅 — 컨텍스트 임계값 경고
# 동작: Claude 응답이 끝날 때마다 현재 컨텍스트 사용량을 확인
#       60% 이상 → 권고 메시지
#       80% 이상 → 경고 메시지

PROJECTS_DIR="$HOME/.claude/projects"

# ── python3 확인 ──────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  exit 0
fi

# ── 가장 최근 세션 파일 탐색 ─────────────────────────────────
LATEST_SESSION=$(find "$PROJECTS_DIR" -name "*.jsonl" -type f 2>/dev/null \
  | xargs ls -t 2>/dev/null \
  | head -1)

if [ -z "$LATEST_SESSION" ]; then
  exit 0
fi

# ── 최신 어시스턴트 메시지에서 토큰 사용량 추출 ──────────────
RESULT=$(python3 -c "
import json, sys
from pathlib import Path

MAX_TOKENS = 200_000
filepath = sys.argv[1]

records = []
try:
    with open(filepath, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try: records.append(json.loads(line))
            except: continue
except Exception:
    sys.exit(0)

# 가장 최근 assistant 메시지의 토큰 사용량
for r in reversed(records):
    if r.get('type') == 'assistant':
        usage = (r.get('message') or {}).get('usage') or {}
        inp   = (usage.get('input_tokens') or 0) + (usage.get('cache_read_input_tokens') or 0)
        out   = usage.get('output_tokens') or 0
        total = inp + out
        if total > 0:
            pct = round(total / MAX_TOKENS * 100)
            print(f'{pct}|{total}|{MAX_TOKENS}')
            sys.exit(0)

sys.exit(0)
" "$LATEST_SESSION" 2>/dev/null)

if [ -z "$RESULT" ]; then
  exit 0
fi

# ── 결과 파싱 ─────────────────────────────────────────────────
PCT=$(echo "$RESULT"  | cut -d'|' -f1)
USED=$(echo "$RESULT" | cut -d'|' -f2)
MAX=$(echo "$RESULT"  | cut -d'|' -f3)

# 숫자 확인 (파싱 실패 방어)
if ! [[ "$PCT" =~ ^[0-9]+$ ]]; then
  exit 0
fi

# ── 임계값별 메시지 출력 ──────────────────────────────────────
if [ "$PCT" -ge 80 ]; then
  echo "" >&2
  echo "🔴 컨텍스트 ${PCT}% 사용 중  ($(printf '%s' "$USED" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta') / $(printf '%s' "$MAX" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta') tokens)" >&2
  echo "   새 작업을 시작한다면 /clear, 현재 작업을 이어간다면 /compact" >&2
  echo "" >&2
elif [ "$PCT" -ge 60 ]; then
  echo "" >&2
  echo "🟡 컨텍스트 ${PCT}% 사용 중  ($(printf '%s' "$USED" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta') / $(printf '%s' "$MAX" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta') tokens)" >&2
  echo "   /compact 실행을 권장합니다." >&2
  echo "" >&2
fi

exit 0
