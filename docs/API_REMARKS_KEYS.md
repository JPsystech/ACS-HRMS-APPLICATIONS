# API remark keys supported by the Flutter app

Use this when implementing or updating backend APIs so remarks are returned and displayed correctly.

## Attendance endpoints

- **GET** `/api/v1/attendance/today`
- **GET** `/api/v1/attendance/my?from=...&to=...`
- **GET** `/api/v1/attendance/list`
- **POST** `/api/v1/attendance/punch-in` / **punch-out** (response)

**Remarks** – the app reads the first non-empty value from these keys (snake_case or camelCase):

- `remarks`
- `remark`
- `punch_remark` / `punchRemark`
- `note`
- `comment`
- `punch_in_remark` / `punchInRemark`
- `punch_out_remark` / `punchOutRemark`
- `action_remark` / `actionRemark`

**Example response (session object):**

```json
{
  "id": "sess-1",
  "employee_id": "E001",
  "work_date": "2026-02-07",
  "punch_in_at": "2026-02-07T09:00:00Z",
  "punch_out_at": "2026-02-07T18:00:00Z",
  "status": "closed",
  "remarks": "Work from home"
}
```

If the backend uses a different key (e.g. `note`), the app will still parse it. Prefer `remarks` for consistency.

---

## Leave endpoints

- **GET** `/api/v1/leaves/list` (or `/leaves/my`, `/leaves/pending`)

**Approved remark** – keys tried in order:

- `approved_remark`, `approvedRemark`
- `approver_remark`, `approverRemark`
- `approval_remark`, `approvalRemark`
- `action_remark`, `actionRemark`

**Rejected remark:**

- `rejected_remark`, `rejectedRemark`
- `reject_remark`, `rejectRemark`
- `action_remark`, `actionRemark`

**Cancelled remark:**

- `cancelled_remark`, `cancelledRemark`
- `cancel_remark`, `cancelRemark`
- `action_remark`, `actionRemark`

**Example leave item:**

```json
{
  "leave_type": "CL",
  "from_date": "2026-02-10",
  "to_date": "2026-02-11",
  "reason": "Personal",
  "status": "approved",
  "approved_remark": "Approved for 2 days",
  "approved_at": "2026-02-08T10:30:00Z",
  "approved_by": { "name": "Manager Name", "emp_code": "M001" }
}
```

**Important: Include cancelled leaves in list**

The Flutter app does **not** filter by status. The **My Leaves** list must include leaves with status `cancelled` (and `rejected`, `approved`, `pending`). If the backend excludes cancelled leaves from the list response, they will not appear in the app. Ensure your list endpoint returns **all** leave records for the user regardless of status.

**Example cancelled leave (must appear in list):**

```json
{
  "leave_type": "CL",
  "from_date": "2026-02-10",
  "to_date": "2026-02-11",
  "reason": "Personal",
  "status": "cancelled",
  "cancelled_remark": "Cancelled by employee request",
  "cancelled_at": "2026-02-09T14:00:00Z",
  "cancelled_by": { "name": "Self", "emp_code": "E001" }
}
```

**Employee reason vs action remarks**

- `reason` (or `description`) = the employee’s reason for requesting leave. Shown as “Reason” in the UI.
- `approved_remark` / `rejected_remark` / `cancelled_remark` = approver/rejector/canceller remark. Shown in the “Action Remark” block.

**Backend checklist:**

1. Ensure DB models store `approved_remark`, `rejected_remark`, `cancelled_remark` (or equivalent).
2. Include these fields in Pydantic response schemas and serializers for list/detail endpoints.
3. On approve/reject/cancel, persist the remark and return the updated leave object including the new remark field(s).
4. **Return cancelled (and all status) leaves in the list endpoint** so they appear in My Leaves.
