#!/usr/bin/env bash
# 이미지 파일명을 SEO 친화적으로 바꾸고, 프로젝트 안의 모든 코드 참조를 함께 갱신한다.
# 사용: bash rename-image.sh <기존경로> <새파일명>
# 예:   bash rename-image.sh assets/IMG_2931.webp hanmac-extra-can-smoooth.webp
set -euo pipefail

OLD="${1:?기존경로 필요}"; NEWNAME="${2:?새파일명 필요}"
[ -f "$OLD" ] || { echo "ERROR: 파일 없음: $OLD" >&2; exit 1; }

DIR=$(dirname "$OLD")
OLDBASE=$(basename "$OLD")
NEW="$DIR/$NEWNAME"
[ -e "$NEW" ] && { echo "ERROR: 대상 이미 존재: $NEW" >&2; exit 1; }

# 파일 이동 (git 저장소면 git mv)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git mv "$OLD" "$NEW"
else
  mv "$OLD" "$NEW"
fi
echo "이동: $OLD -> $NEW"

# 참조 갱신: 파일명(basename) 기준으로 코드 내 텍스트 참조 교체
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
updated=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  sed -i.bak "s|$OLDBASE|$NEWNAME|g" "$file" && rm -f "$file.bak"
  echo "참조 갱신: $file"
  updated=$((updated+1))
done < <(grep -rlI --exclude-dir=.git "$OLDBASE" "$ROOT" || true)

echo "---"
echo "코드 내 참조 ${updated}곳 갱신."
echo "⚠ 코드 밖 참조(CMS·DB·SEO 메타 관리자·외부 링크)는 자동으로 못 잡는다 — 직접 확인 요망."
