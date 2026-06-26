/** Resolve human-readable PM inspection defects from form_values + form_structure. */

function str(v: unknown): string {
  return (v ?? "").toString().trim();
}

function asRecord(v: unknown): Record<string, unknown> {
  return v && typeof v === "object" ? (v as Record<string, unknown>) : {};
}

export function buildPmFieldLabelMap(
  formStructure: unknown,
): Map<string, string> {
  const labels = new Map<string, string>();
  const root = asRecord(formStructure);
  const sections = root.sections;
  if (!Array.isArray(sections)) return labels;

  for (const sec of sections) {
    if (!sec || typeof sec !== "object") continue;
    const fields = (sec as Record<string, unknown>).fields;
    if (!Array.isArray(fields)) continue;
    for (const field of fields) {
      if (!field || typeof field !== "object") continue;
      const m = field as Record<string, unknown>;
      const id = str(m.id);
      const label = str(m.label);
      if (id && label) labels.set(id, label);
    }
  }
  return labels;
}

export type PmDefectSummary = {
  task_id: string;
  task: string;
  comment: string;
};

export function extractPmDefects(
  formValues: unknown,
  formStructure?: unknown,
): PmDefectSummary[] {
  const fv = asRecord(formValues);
  const labels = buildPmFieldLabelMap(formStructure);
  const seen = new Set<string>();
  const defects: PmDefectSummary[] = [];

  const push = (taskId: string, comment: string) => {
    if (!taskId || seen.has(taskId)) return;
    seen.add(taskId);
    const task = labels.get(taskId) ?? taskId;
    defects.push({ task_id: taskId, task, comment });
  };

  const mobile = asRecord(fv.__mobile_v1);
  const stored = mobile.defects;
  if (Array.isArray(stored)) {
    for (const row of stored) {
      const d = asRecord(row);
      const taskId = str(d.task_id);
      const task = str(d.task) || labels.get(taskId) || taskId;
      const comment = str(d.comment);
      if (!taskId) continue;
      seen.add(taskId);
      defects.push({ task_id: taskId, task, comment });
    }
    if (defects.length > 0) return defects;
  }

  const formData = asRecord(mobile.form_data);
  const scheduleValues = asRecord(formData.schedule_form_values);
  for (const [taskId, raw] of Object.entries(scheduleValues)) {
    const entry = asRecord(raw);
    if (str(entry.status) === "defective") {
      push(taskId, str(entry.comment));
    }
  }

  for (const [key, val] of Object.entries(fv)) {
    if (key.startsWith("__")) continue;
    if (val === "defective") push(key, "");
  }

  return defects;
}

export function formatPmDefectsForPrompt(defects: PmDefectSummary[]): string {
  if (!defects.length) return "No defective checklist items recorded.";
  return defects
    .map((d) => (d.comment ? `${d.task}: ${d.comment}` : d.task))
    .join("; ");
}
