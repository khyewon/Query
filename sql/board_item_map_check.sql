-- Board 상 보여지는 mapping 확인 쿼리

WITH base_detail AS (
SELECT
  CASE
    WHEN CAST(REPLACE(x.line, 'G', '') AS UNSIGNED) BETWEEN 1  AND 20  THEN 1
    WHEN CAST(REPLACE(x.line, 'G', '') AS UNSIGNED) BETWEEN 21 AND 40  THEN 2
    WHEN CAST(REPLACE(x.line, 'G', '') AS UNSIGNED) BETWEEN 41 AND 60  THEN 3
  END AS 'ZONE',
  x.line AS 'Line No',
  CASE x.seq
    WHEN 1 THEN 'Current'
    ELSE 'Next'
  END 'PO Type',
  x.unit_id,
  CONCAT(LEFT(y.src_part_id, 2), '-', SUBSTRING_INDEX(y.src_part_id, '-', -1)) AS part_type,
  y.src_part_id,
  y.sys_part_id,
  CASE
    WHEN z.op_code = 'P1' AND z.work_seq = 2 AND z.process_status = 'COMPLETE' THEN 'Step2'
    ELSE z.op_desc
  END op_desc,
  CASE
    WHEN z.op_code = 'P1' AND z.work_seq = 2 AND z.process_status = 'COMPLETE' THEN 'P2'
    ELSE z.op_code
  END op_code,
  z.process_status,
  m.eqp_cd,    -- 26/09/14 : Equipment 정보 추가
  m.eqp_desc,  -- 26/09/14 : Equipment 정보 추가
  z.start_dt,
  z.end_dt,
  CONVERT_TZ(y.updated_at, '+00:00', '-06:00') AS 'map_time(local)',
  CASE
    WHEN z.op_code = 'P1' AND z.work_seq = 2 AND z.process_status = 'COMPLETE' THEN 2
    WHEN z.op_code IN ('P1') THEN 1
    WHEN z.op_code IN ('P2', 'P2B') THEN 2
    WHEN z.op_code IN ('P3-A','P3-B','P3-C','P3-D','P3-E','P3-F') THEN 3
    ELSE 0
  END part_status,
  CASE    -- 26/09/18 최신 이력이 없거나 최신 상태가 'D'이면 'N', 그 외는 'Y'
    WHEN k.sub_item_id is null OR k.change_flag = 'D' THEN 'N'
    ELSE 'Y'
  END 'S3_flag'
FROM
  (
    SELECT
      g.line,
      g.proj_id,
      g.unit_id,
      g.seq
    FROM
      (
        SELECT
          ROW_NUMBER() OVER (
            PARTITION BY line ORDER BY a.ms_dt
          ) AS seq,
          a.*
        FROM
          work_plan a
        WHERE
          a.created_year = YEAR(CURDATE())
          AND a.created_week = WEEK(CURDATE(), 3)
          AND a.site_type = 'S1'
          AND a.done_dt is null
      ) g
    WHERE g.seq <= 2
  ) x
  INNER JOIN item_map y ON x.proj_id = y.proj_id
                              AND y.src_part_id like CONCAT(x.unit_id, '%')
  INNER JOIN proj t ON x.proj_id = t.id
  INNER JOIN wip_log z ON t.ext_proj_id = z.ext_proj_id
                              AND y.sys_part_id = z.item_id
  LEFT JOIN equipment m on z.eqp_id = m.eqp_id    -- 26/09/14 : Equipment 정보 추가
  -- 26/09/18 part_input에서 자재별 최신 1건(updated_at DESC)만 추출하여 조인
  LEFT JOIN (SELECT proj_id, item_id, sub_item_id, change_flag, updated_at
                 FROM (SELECT mi.*, ROW_NUMBER() OVER (
                     PARTITION BY mi.proj_id, mi.item_id, mi.sub_item_id
                     ORDER BY mi.updated_at DESC
                 ) AS rn
             FROM part_input mi
             ) ranked_k
         WHERE rn = 1
  ) k ON t.ext_proj_id = k.proj_id
      AND z.item_id = k.sub_item_id
      AND x.unit_id = k.item_id
WHERE
  CAST(REPLACE(x.line, 'G', '') AS UNSIGNED) BETWEEN 41 AND 60  -- ZONE 3 조회 조건
ORDER BY
  x.seq,
  CAST(x.line AS UNSIGNED),
  CAST(
    REGEXP_SUBSTR(src_part_id, '[0-9]+$') AS UNSIGNED
  )
)
SELECT * FROM base_detail
  WHERE part_status > 0  -- 26/9/14 : P1 이상 진행된 항목만 조회
  AND part_type = 'XK-R4'
  AND S3_flag = 'N';  -- 26/9/18 : S3 안된 항목만 조회
