-- Site S1 jobs for processes K1-K7 on current-week plan units,
-- with item mapping, equipment and process info.
-- Timestamps converted from UTC to local time.

SELECT j.shift_key, j.site_type, j.area, j.item_id, im.sys_part_id, j.pair_part_id, j.item_kind, LEFT(j.item_id, 7) AS unit_id,
        wp.line, wp.ms_dt AS due_date,
        p.proc_cd, m.eqp_no,
        CONVERT_TZ(j.planned_start_dt, '+00:00', '-06:00') AS plan_start_time, CONVERT_TZ(j.planned_end_dt, '+00:00', '-06:00') AS plan_end_time,
        CONVERT_TZ(j.actual_start_dt, '+00:00', '-06:00') AS actual_start_time, CONVERT_TZ(j.actual_end_dt, '+00:00', '-06:00') AS actual_end_time, j.process_status,
        CONVERT_TZ(j.created_at, '+00:00', '-06:00') AS first_generated_time, CONVERT_TZ(j.updated_at, '+00:00', '-06:00') AS updated_time,
        j.is_locked
  FROM job j
    JOIN item_map im ON j.item_id = im.src_part_id
    JOIN work_plan wp ON wp.unit_id = LEFT(j.item_id, 7)
    JOIN equipment m ON j.eqp_id = m.eqp_id
    JOIN proc p ON j.proc_id = p.id
    JOIN job_snap js ON j.id = js.job_id
  WHERE j.site_type = 'S1'
      AND j.shift_key >= '20250101-1'
      AND wp.site_type = 'S1'
      AND wp.created_week = WEEKOFYEAR(DATE(CONVERT_TZ(NOW(), '+00:00', '-06:00')))
      AND p.proc_cd IN ('K1', 'K2', 'K3', 'K4', 'K5', 'K6', 'K7')
      AND j.planned_start_dt IS NOT NULL
      AND j.work_seq = 1
      -- AND js.generated_at = (SELECT generated_at FROM job_snap ORDER BY generated_at DESC LIMIT 1)
  ORDER BY FIELD(p.proc_cd, 'K1', 'K2', 'K3', 'K4', 'K6', 'K5', 'K7'), j.shift_key, j.area, j.planned_start_dt, m.eqp_no, wp.unit_id;
