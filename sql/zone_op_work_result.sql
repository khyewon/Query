-- 단위(Unit)별 자재 매핑 / WO / 실작업결과 조회
-- Zone 3 (lines 41-60), site S1, 특정 공정(OP-L) 대상.
-- Timestamps converted from UTC to local time.

WITH
  mapped_item_wip AS (
    SELECT
      wl.ext_proj_id, wl.proj_id,
      CASE WHEN wl.item_kind LIKE 'XK%' THEN LEFT(wl.item_id, 7) ELSE wl.item_id END 'unit_id',
      wl.item_id AS 'src_item_id', wl.sys_item_id, wl.op_desc, wl.op_id,
      wl.progress, wl.process_status, CONVERT_TZ(wl.start_dt, '+00:00', '-06:00') AS 'job_on', CONVERT_TZ(wl.end_dt, '+00:00', '-06:00') AS 'job_off'
    FROM wip_log wl
    WHERE wl.ext_proj_id >= 1000
      AND wl.item_kind <> 'DX'
      AND wl.work_seq = 1
),
  plan_with_item AS (
    SELECT
      wp.created_week, wp.proj_id,
      wp.unit_id,
      CASE WHEN wp.line BETWEEN 1 AND 20 THEN 'ZONE1' WHEN wp.line BETWEEN 21 AND 40 THEN 'ZONE2' WHEN wp.line BETWEEN 41 AND 60 THEN 'ZONE3' ELSE 'ETC' END AS 'zone', wp.line,
      CONCAT(LEFT(im.src_part_id, 2), '-', SUBSTRING_INDEX(im.src_part_id, '-', -1)) AS part_type,
      im.src_part_id, im.sys_part_id,
      CONVERT_TZ(im.updated_at, '+00:00', '-06:00') AS 'map_updated',
      wp.updated_by_user, wp.plan_dt, wp.expect_dt, wp.ms_dt, CONVERT_TZ(wp.updated_at, '+00:00', '-06:00') AS 'plan_updated(local)'
    FROM work_plan wp
      JOIN item_map im ON LEFT(im.src_part_id,7) = wp.unit_id
    WHERE wp.done_dt IS NULL
      AND wp.created_week = WEEKOFYEAR(CONVERT_TZ(CURDATE(), '+00:00', '-06:00'))
      AND wp.site_type = 'S1'
),
  wo_with_operator AS (
    SELECT we.proj_id, we.sys_item_id, we.process_status,
      p.op_id, e.eqp_desc, we.shift_key, o.operator_nm
    FROM work_exec we
      JOIN proc p ON p.id = we.proc_id
      JOIN operator o ON o.id = we.operator_id
      JOIN equipment e ON e.eqp_id = we.eqp_id
    WHERE p.site_type = 'S1'
      AND we.work_seq = 1
)
SELECT miw.ext_proj_id, pwi.zone, miw.unit_id, pwi.line,
        miw.src_item_id, miw.sys_item_id, pwi.part_type, pwi.map_updated, pwi.plan_dt, pwi.expect_dt, pwi.ms_dt,
        wwo.shift_key, miw.op_desc, miw.progress, miw.process_status, wwo.eqp_desc, wwo.operator_nm, miw.job_on, miw.job_off
FROM mapped_item_wip miw
  JOIN plan_with_item pwi ON pwi.proj_id = miw.proj_id AND pwi.unit_id = miw.unit_id AND pwi.sys_part_id = miw.sys_item_id
  JOIN wo_with_operator wwo ON wwo.proj_id = miw.proj_id AND wwo.sys_item_id = miw.sys_item_id  AND wwo.op_id = miw.op_id AND wwo.process_status = miw.process_status
WHERE pwi.zone = 'ZONE3'
  AND miw.op_desc = 'OP-L'
ORDER BY pwi.zone, pwi.line, pwi.part_type, ms_dt;
