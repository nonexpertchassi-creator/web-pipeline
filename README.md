# web-pipeline (팀 마켓플레이스)

웹 제작 파이프라인 4단계 작업 지침을 담은 **팀 내부용** Claude 플러그인 마켓플레이스.

## 담긴 플러그인

- **web-pipeline** — 기획·디자인·마크업·프론트 4단계 스킬 + 단계별 핸드오프 기록. (PHP 백엔드 + JS 프론트 분리 구조 기준)

## 팀에 배포하기 (관리자 = 나)

1. 이 폴더를 **비공개(private) 깃 레포**로 올린다.
   ```bash
   git init
   git add .
   git commit -m "web-pipeline plugin marketplace"
   git remote add origin git@github.com:<우리-조직>/web-pipeline.git   # private 레포
   git push -u origin main
   ```
2. 레포를 private으로 두고 팀원만 접근 권한을 준다. → 팀원만 볼 수 있음.

## 팀원이 설치하기 (한 번만)

평소 사내 private 레포를 클론할 수 있는 상태(SSH 키/토큰 인증)면 추가 설정 없이:

```
/plugin marketplace add <우리-조직>/web-pipeline
/plugin install web-pipeline@web-pipeline
```

설치 후 `web-pipeline` 스킬 4종이 활성화된다.

## 업데이트 흐름

- 내가 스킬 내용을 고쳐 **깃에 푸시**하면, 그게 곧 새 버전이 된다.
  (`plugin.json`에 `version`을 비워둬서 **커밋 SHA = 버전** → 푸시마다 새 버전 인식)
- 팀원 쪽에서 최신을 받는 방법:
  - **자동**: 팀원이 이 마켓플레이스의 자동 업데이트를 켜두면 시작 시 자동 반영.
  - **수동**: `/plugin marketplace update` 후 `/reload-plugins`.
- private 레포 자동 업데이트는 토큰이 필요하다 (`GITHUB_TOKEN` 등 환경변수). 수동 업데이트는 평소 git 인증으로 동작.

## 조직 단위로 강제하고 싶으면 (선택)

팀 레포의 `.claude/settings.json`에 아래를 넣으면, 팀원이 프로젝트를 신뢰할 때 이 마켓플레이스를 자동으로 인식한다.

```json
{
  "extraKnownMarketplaces": {
    "web-pipeline": {
      "source": { "source": "github", "repo": "<우리-조직>/web-pipeline" }
    }
  },
  "enabledPlugins": {
    "web-pipeline@web-pipeline": true
  }
}
```

## 구조

```
web-pipeline/                         ← 깃 레포 루트
├── .claude-plugin/marketplace.json   ← 마켓플레이스 카탈로그
└── plugins/
    └── web-pipeline/                 ← 실제 플러그인
        ├── .claude-plugin/plugin.json
        ├── skills/{web-planning,web-design,web-markup,web-frontend}/SKILL.md
        └── README.md
```
