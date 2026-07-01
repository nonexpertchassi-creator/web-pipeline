#!/usr/bin/env bash
# 마크업 self-QA 자동 점검 — 기계가 판단 없이 잡을 수 있는 것만.
# (디자인 대조·기기·스크린리더 등 판단이 필요한 QA는 reference/qa-checklist.md로 사람이.)
# 사용: bash qa-check.sh [대상폴더]
set -uo pipefail

DIR="${1:-.}"
ROOT="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null || echo "$DIR")"
INC=(--include='*.html' --include='*.htm' --include='*.php' --include='*.jsx' --include='*.tsx' --include='*.vue' --include='*.js' --include='*.ts' --include='*.css' --include='*.scss')
issues=0

echo "== 1) 1MB 초과 미변환 이미지(webp 변환 후보) =="
big=$(find "$DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -size +1048576c 2>/dev/null)
if [ -n "$big" ]; then echo "$big" | sed 's/^/  - /'; issues=$((issues+1)); else echo "  없음"; fi

echo "== 2) alt 없는 <img> (한 줄 기준, best-effort) =="
noalt=$(grep -rnIE --exclude-dir=.git "${INC[@]}" '<img[^>]*>' "$ROOT" 2>/dev/null | grep -v 'alt=' || true)
if [ -n "$noalt" ]; then echo "$noalt" | sed 's/^/  - /'; issues=$((issues+1)); else echo "  없음"; fi

echo "== 3) <div>/<span> onclick 안티패턴 =="
onclick=$(grep -rnIE --exclude-dir=.git "${INC[@]}" '<(div|span)[^>]*onclick=' "$ROOT" 2>/dev/null || true)
if [ -n "$onclick" ]; then echo "$onclick" | sed 's/^/  - /'; issues=$((issues+1)); else echo "  없음"; fi

echo "== 4) 깨진 이미지 참조(로컬 파일 없음, best-effort) =="
refs=$(grep -rhoIE --exclude-dir=.git "${INC[@]}" '[A-Za-z0-9._/-]+\.(webp|png|jpe?g|svg|gif)(\?[A-Za-z0-9._=%-]*)?' "$ROOT" 2>/dev/null | sed -E 's/\?.*$//' | sort -u || true)
broken=""
while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  case "$ref" in *//*|data:*) continue;; esac   # 외부 URL/data URI 제외
  b=$(basename "$ref")
  if ! find "$ROOT" -type f -name "$b" -not -path '*/.git/*' 2>/dev/null | grep -q .; then
    broken="${broken}  - ${ref}
"
  fi
done <<< "$refs"
if [ -n "$broken" ]; then printf '%s' "$broken"; issues=$((issues+1)); else echo "  없음"; fi

echo "== 5) 남은 더미·미완성 표시·깨진 글자 =="
d1=$(grep -rniI --exclude-dir=.git "${INC[@]}" 'lorem ipsum' "$ROOT" 2>/dev/null || true)
d2=$(grep -rnI  --exclude-dir=.git "${INC[@]}" -e 'TODO' -e 'FIXME' "$ROOT" 2>/dev/null || true)
d3=$(grep -rnI  --exclude-dir=.git "${INC[@]}" "$(printf '\357\277\275')" "$ROOT" 2>/dev/null || true)
dummy=$(printf '%s\n%s\n%s\n' "$d1" "$d2" "$d3" | grep -v '^$' || true)
if [ -n "$dummy" ]; then echo "$dummy" | sed 's/^/  - /'; issues=$((issues+1)); else echo "  없음"; fi
echo "  (진짜 맞춤법·오탈자는 기계가 못 잡음 — Claude가 문맥 보고 플래그, 의도적 오타는 존중. qa-checklist.md 참고)"

echo "---"
if [ "$issues" -gt 0 ]; then
  echo "⚠ 자동 점검에서 짚을 게 있어요(${issues}개 항목). 위 목록 확인."
  echo "  기계가 잡는 부분만입니다 — 디자인 대조·반응형·기기·스크린리더 등은 reference/qa-checklist.md로 사람이 확인."
  exit 1
else
  echo "자동 점검 통과. 판단이 필요한 QA는 reference/qa-checklist.md 참고."
fi
