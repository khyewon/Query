-- Zone C (lines 41-60), site S1: current-week plan rows (done_dt not set)
-- joined with item_map, wip_status and equipment.
-- Timestamps converted from UTC to local time.

SELECT wp.created_week,
        pj.proj_no,
        wp.unit_id,
        CONCAT(LEFT(im.src_part_id, 2), '-', SUBSTRING_INDEX(im.src_part_id, '-', -1)) AS part_type,
        im.src_part_id, im.sys_part_id,
        CONVERT_TZ(im.updated_at, '+00:00', '-06:00') AS 'map_updated(local)',
        ws.op_desc, e.eqp_desc,
        wp.line, wp.updated_by_user, wp.plan_dt, wp.expect_dt, wp.ms_dt, CONVERT_TZ(wp.updated_at, '+00:00', '-06:00') AS 'plan_updated(local)'
FROM work_plan wp
    JOIN item_map im ON LEFT(im.src_part_id,7) = wp.unit_id
    JOIN proj pj ON pj.id = wp.proj_id
    JOIN wip_status ws ON ws.item_id = im.sys_part_id
    JOIN equipment e ON e.eqp_id = ws.eqp_id
WHERE wp.done_dt IS NULL
  AND wp.created_week = WEEKOFYEAR(CURRENT_DATE())
  AND pj.ext_proj_id in (2081, 2946, 3317, 4702)
  AND wp.line BETWEEN 41 AND 60   -- ZONE C
  AND wp.site_type = 'S1'
  AND ws.site_type = 'S1'
  AND op_desc IS NOT NULL
ORDER BY wp.line, wp.ms_dt, wp.unit_id, wp.updated_at;
