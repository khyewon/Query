-- Site S1: current-week plan rows (done_dt not set, confirmed projects)
-- left-joined with item_map per unit. One row per unit / part type / line.
-- Timestamps converted from UTC to local time.

WITH mapping AS (
    SELECT im.proj_id, LEFT(im.src_part_id, 7) AS unit_id, im.src_part_id, im.sys_part_id,
        CONVERT_TZ(im.updated_at, '+00:00', '-06:00') AS 'map_updated(local)'
    FROM item_map im
),
week_plan AS (
    SELECT wp.proj_id, pj.ext_proj_id, wp.unit_id, wp.line, wp.updated_by_user,
        CONVERT_TZ(wp.plan_dt, '+00:00', '-06:00')    AS 'plan_dt(local)',
        CONVERT_TZ(wp.expect_dt, '+00:00', '-06:00')  AS 'expect_dt(local)',
        CONVERT_TZ(wp.deleted_at, '+00:00', '-06:00') AS 'deleted_at(local)',
        CONVERT_TZ(wp.ms_dt, '+00:00', '-06:00')      AS 'ms_dt(local)',
        CONVERT_TZ(wp.updated_at, '+00:00', '-06:00') AS 'plan_updated(local)'
    FROM work_plan wp
        JOIN proj pj ON pj.id = wp.proj_id
    WHERE wp.created_year = YEAR(CONVERT_TZ(CURRENT_DATE(), '+00:00', '-06:00'))
      AND wp.created_week = WEEKOFYEAR(CONVERT_TZ(CURRENT_DATE(), '+00:00', '-06:00'))
      AND wp.site_type = 'S1'
      AND wp.done_dt IS NULL
      AND pj.status = 'confirmed'
)
SELECT pl.ext_proj_id, pl.unit_id,
    CONCAT(SUBSTRING(mp.src_part_id, 1, 2), SUBSTRING(mp.src_part_id FROM 6)) AS part_type,
    mp.sys_part_id, mp.`map_updated(local)`,
    pl.line, pl.updated_by_user,
    pl.`plan_dt(local)`, pl.`expect_dt(local)`, pl.`deleted_at(local)`, pl.`ms_dt(local)`, pl.`plan_updated(local)`
FROM week_plan pl
    LEFT JOIN mapping mp ON mp.unit_id = pl.unit_id AND mp.proj_id = pl.proj_id
WHERE pl.unit_id IN ('XX001-A')
  -- AND mp.src_part_id IN ('XX002-B1', 'XX002-B2', 'XX003-B1', 'XX003-B2')
  -- AND mp.sys_part_id IN ('XX002-B6', 'YY101-B3', 'YY102-B4', 'XX003-B7')
  -- AND pl.unit_id IN ('XX002-B', 'XX004-B')
  -- AND pl.line BETWEEN 41 AND 60
  -- AND mp.src_part_id IN (SELECT src_part_id FROM item_map_history WHERE sys_part_id LIKE 'YY%M6')
GROUP BY mp.unit_id, part_type, pl.line
ORDER BY pl.`ms_dt(local)`, part_type;
