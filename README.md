# Query

제조 현장 운영 데이터(생산계획·공정 진행·설비·자재 매핑)를 조회하기 위해 작성한 SQL 쿼리 모음입니다.
모든 테이블명·컬럼명·코드값·식별자는 익명화되어 있으며 실제 시스템과 무관합니다.

- DBMS: MySQL 8.x (윈도 함수, `REGEXP_SUBSTR`, `CONVERT_TZ` 사용)

## 구성

```
sql/
├── zone_plan_item_map.sql     # 금주 생산계획 ↔ 자재 매핑 ↔ 공정 현황
├── board_item_map_check.sql   # 현황판 표시 매핑 검증
├── area_job_list.sql          # 공정별 작업(Job) 계획·실적 목록
└── zone_op_work_result.sql    # 금주 계획 단위의 자재 매핑·WO·실작업결과
```

## 쿼리 설명

### `zone_plan_item_map.sql`
특정 구역(라인 41–60)의 금주 미완료 생산계획을 자재 매핑·공정 진행·설비 정보와 결합해 조회합니다.
- `work_plan` → `item_map` → `wip_status` → `equipment` 다중 조인
- 대상 프로젝트 필터, UTC → 현지 시각 변환

### `board_item_map_check.sql`
현황판에 표시되는 라인별 현재/다음 생산 단위의 자재 매핑 상태를 검증합니다.
- `ROW_NUMBER()`로 라인별 현재(1순위)·다음(2순위) 계획 추출
- 공정 코드와 작업 차수를 조합해 진행 단계(`part_status`) 산출
- 투입 이력에서 자재별 최신 1건만 추출해 후속 공정 반영 여부(`S3_flag`) 판정
- CTE로 상세 데이터를 구성한 뒤 조건 필터링

### `area_job_list.sql`
금주 계획 대상 단위의 공정(K1–K7)별 작업 계획·실적 시간을 조회합니다.
- `job` → `item_map` / `work_plan` / `equipment` / `proc` / `job_snap` 조인
- 계획·실적 시작/종료 시각의 시간대 변환
- `FIELD()`로 공정 순서 지정 정렬

### `zone_op_work_result.sql`
금주 미완료 생산계획 단위의 자재 매핑, 작업지시(WO), 실작업결과를 결합해 특정 구역(Zone 3)·특정 공정(`OP-L`) 기준으로 조회합니다.
- CTE 3개로 구성: 공정 진행 이력(`mapped_item_wip`), 금주 계획 ↔ 자재 매핑(`plan_with_item`), 작업 실행 ↔ 작업자·설비(`wo_with_operator`)
- 자재 종류에 따라 자재 ID 앞 7자리로 단위 ID 산출, 라인 번호로 구역(`ZONE1`–`ZONE3`) 구분
- 프로젝트·자재·공정·진행 상태 기준 조인으로 WO와 실작업 시각(`job_on`/`job_off`) 연결
- UTC → 현지 시각 변환
