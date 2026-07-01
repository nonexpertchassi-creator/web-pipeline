#!/usr/bin/env bash
# 이미지 참조에 날짜+순번 버전 쿼리(?v=YYMMDD[-N])를 붙인다.
# - 첫 등장 이미지: 버전 안 붙임(기록만).  - 내용이 바뀐 이미지만 버전 갱신.
# - 같은 날 여러 번 바뀌면 260630 -> 260630-2 -> 260630-3.  - 안 바뀌면 그대로(idempotent).
# 상태는 매니페스트(image-versions.tsv: 파일명<TAB>해시<TAB>버전)에 기록. 팀 공유 위해 커밋 권장.
# 사용: bash stamp-image-versions.sh [이미지폴더] [검색루트] [매니페스트경로]
set -euo pipefail

IMG_DIR="${1:-.}"
ROOT="${2:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"
MANIFEST="${3:-$ROOT/image-versions.tsv}"
TODAY="${STAMP_TODAY:-$(date +%y%m%d)}"
MANBASE=$(basename "$MANIFEST")

hash8() {
  if command -v shasum >/dev/null 2>&1; then shasum "$1" | awk '{print substr($1,1,8)}'
  elif command -v sha1sum >/dev/null 2>&1; then sha1sum "$1" | awk '{print substr($1,1,8)}'
  else md5 -q "$1" | cut -c1-8; fi
}
esc_ere() { printf '%s' "$1" | sed -e 's/[.[\*^$()+?{|]/\\&/g'; }

[ -f "$MANIFEST" ] || : > "$MANIFEST"
CURLIST=$(mktemp); NEWMAN=$(mktemp); STAMPLIST=$(mktemp)
trap 'rm -f "$CURLIST" "$NEWMAN" "$STAMPLIST"' EXIT

# 현재 이미지: 파일명<TAB>해시
while IFS= read -r -d '' img; do
  printf '%s\t%s\n' "$(basename "$img")" "$(hash8 "$img")"
done < <(find "$IMG_DIR" -type f \( -iname '*.webp' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.svg' -o -iname '*.gif' \) -print0) > "$CURLIST"

# 매니페스트 대조 → 새 매니페스트 + 스탬프 목록(변경분만)
awk -v today="$TODAY" -v manout="$NEWMAN" -v manfile="$MANIFEST" '
  FILENAME==manfile { oh[$1]=$2; ov[$1]=$3; next }
  {
    base=$1; cur=$2
    if (!(base in oh))       { nh[base]=cur; nv[base]="-" }
    else if (oh[base]==cur)  { nh[base]=cur; nv[base]=ov[base] }
    else {
      o=ov[base]
      if (substr(o,1,6)==today) {
        if (length(o)==6) n=2; else { split(o,a,"-"); n=a[2]+1 }
        vv=today "-" n
      } else vv=today
      nh[base]=cur; nv[base]=vv; stamp[base]=vv
    }
  }
  END {
    for (b in nh) print b "\t" nh[b] "\t" nv[b] > manout
    for (b in stamp) print b "\t" stamp[b]
  }
' "$MANIFEST" "$CURLIST" > "$STAMPLIST"
mv "$NEWMAN" "$MANIFEST"

# 변경된 이미지만 참조에 스탬프
stamped=0
while IFS=$'\t' read -r base ver; do
  [ -z "$base" ] && continue
  ebase=$(esc_ere "$base")
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    sed -E -i.bak "s#${ebase}(\?v=[A-Za-z0-9._-]+)?#${base}?v=${ver}#g" "$f" && rm -f "$f.bak"
    echo "스탬프: $f  ($base -> ?v=$ver)"
    stamped=$((stamped+1))
  done < <(grep -rlIF --exclude-dir=.git --exclude="$MANBASE" "$base" "$ROOT" || true)
done < "$STAMPLIST"

echo "---"
echo "변경 반영 ${stamped}건. 매니페스트: $MANIFEST (커밋해 팀과 공유)."
echo "⚠ 실제 캐시 지속시간(Cache-Control)은 서버 설정 — CDN이 쿼리스트링을 캐시 키로 봐야 적용됨."
echo "⚠ 코드 밖 참조(CMS·DB·SEO 관리자)는 못 잡음. 변경은 git diff로 검토 권장."
