USE capstone_project;

-- 1. Identify where and when the crime happened:
SELECT room as crime_location, description, found_time FROM evidence;

-- 2. Analyze who accessed critical areas at the time:
SELECT e.employee_id, e.name, k.room, k.entry_time, k.exit_time
FROM employees e
JOIN keycard_logs k ON e.employee_id = k.employee_id
WHERE k.room = 'CEO Office'
  AND k.entry_time BETWEEN '2025-10-15 20:45:00' AND '2025-10-15 21:15:00';

-- 3. Cross-check alibis with actual logs:
SELECT 
    a.employee_id,
    e.name,
    a.claimed_location,
    TIME(a.claim_time) AS claim_time,
    COALESCE(k.room, '-') AS actual_location,
    COALESCE(TIME(k.entry_time), '-') AS entry_time,
    COALESCE(TIME(k.exit_time), '-') AS exit_time
FROM alibis a
LEFT JOIN employees e 
       ON e.employee_id = a.employee_id
LEFT JOIN keycard_logs k
       ON k.employee_id = a.employee_id
      AND a.claim_time BETWEEN k.entry_time AND k.exit_time;

-- 4. Investigate suspicious calls made around the time:
SELECT c.call_id,
       c.caller_id, caller.name AS caller_name,
       c.receiver_id, receiver.name AS receiver_name,
       c.call_time, c.duration_sec
FROM calls c
LEFT JOIN employees caller   ON c.caller_id = caller.employee_id
LEFT JOIN employees receiver ON c.receiver_id = receiver.employee_id
WHERE c.call_time BETWEEN '2025-10-15 20:30:00' AND '2025-10-15 21:00:00'
ORDER BY c.call_time;

-- 5. Match evidence with movements and claims:
SELECT
    ev.room,
    ev.description,
    TIME(ev.found_time) AS found_time,
    CASE
        WHEN TIME(k.entry_time) BETWEEN '20:30:00' AND '21:00:00'
         AND TIME(k.exit_time)  BETWEEN '21:00:00' AND '21:30:00'
        THEN e.name
        ELSE '-'
    END AS suspect_name,
    CASE
        WHEN TIME(k.entry_time) BETWEEN '20:30:00' AND '21:00:00'
        THEN TIME(k.entry_time)
        ELSE '-'
    END AS entry_time,
    CASE
        WHEN TIME(k.exit_time) BETWEEN '21:00:00' AND '21:30:00'
        THEN TIME(k.exit_time)
        ELSE '-'
    END AS exit_time
FROM evidence AS ev
LEFT JOIN keycard_logs AS k
    ON ev.room = k.room
LEFT JOIN employees AS e
    ON k.employee_id = e.employee_id
WHERE ev.room = 'CEO Office'
ORDER BY ev.found_time;

-- 6. Combine all findings to identify the killer: case solved
SELECT emp.name as killer_name
FROM employees emp
WHERE employee_id IS NOT NULL
 AND EXISTS ( 
    SELECT 1 FROM keycard_logs k   #presence in CEO Office near crime
    WHERE k.employee_id = emp.employee_id
      AND k.room = 'CEO Office'
      AND k.entry_time BETWEEN '2025-10-15 20:45:00' AND '2025-10-15 21:15:00'
)
AND EXISTS (
    SELECT 1 FROM calls c    #call in suspicious window
    WHERE (c.caller_id = emp.employee_id OR c.receiver_id = emp.employee_id)
      AND c.call_time BETWEEN '2025-10-15 20:50:00' AND '2025-10-15 21:00:00'
)
AND EXISTS (
    SELECT 1 FROM alibis a   #has at least one alibi that doesn't match keycard logs
    WHERE a.employee_id = emp.employee_id
      AND NOT EXISTS (
          SELECT 1 FROM keycard_logs k2
          WHERE k2.employee_id = a.employee_id
            AND a.claim_time BETWEEN k2.entry_time AND k2.exit_time
            AND k2.room = a.claimed_location
      )
);