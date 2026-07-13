import type { Env } from '../types';
import { getSupabase } from './supabase';
import { generateStudentReport, generateClassroomReport, type StudentReport, type ClassroomReport } from './reports';

/**
 * PDF report service — Task 8.2, 8.3, 9.2.
 *
 * Cloudflare Workers cannot run jsPDF/puppeteer (no DOM, no headless browser).
 * Instead, we generate a clean printable HTML document with print CSS that
 * teachers can save as PDF via the browser's "Print to PDF" feature.
 *
 * The HTML embeds teacher branding (custom logo + colors) + OSEE footer.
 *
 * A real PDF binary can be generated later via:
 *   - A separate Worker that calls an external PDF microservice, OR
 *   - R2-hosted headless Chrome (e.g. browser-rendering API).
 */

export interface ReportHtmlOptions {
  branding?: {
    teacher_name?: string;
    primary_color?: string;
    logo_url?: string | null;
    hide_osee_branding?: boolean;
  };
}

/** Get branding config for a teacher (Task 15.1). */
async function getBranding(env: Env, teacherId: string): Promise<ReportHtmlOptions['branding']> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('branding_configs')
    .select('logo_url, primary_color, hide_osee_branding')
    .eq('teacher_id', teacherId)
    .eq('active', true)
    .maybeSingle();
  if (!data) return undefined;
  const b = data as Record<string, unknown>;
  return {
    logo_url: (b.logo_url as string) ?? null,
    primary_color: (b.primary_color as string) ?? '#CCFF00',
    hide_osee_branding: (b.hide_osee_branding as boolean) ?? false,
  };
}

/** Get teacher display name. */
async function getTeacherName(env: Env, teacherId: string): Promise<string> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('unified_profiles')
    .select('display_name')
    .eq('id', teacherId)
    .maybeSingle();
  return (data as Record<string, unknown> | null)?.display_name as string ?? 'Teacher';
}

/** Generate student report as printable HTML. */
export async function generateStudentReportHtml(
  env: Env,
  teacherId: string,
  studentId: string
): Promise<{ html: string; filename: string }> {
  const report = await generateStudentReport(env, teacherId, studentId);
  const teacherName = await getTeacherName(env, teacherId);
  const branding = (await getBranding(env, teacherId)) ?? {};
  branding.teacher_name = teacherName;

  const html = renderStudentReportHtml(report, { branding });
  const filename = `student_report_${report.student.name.replace(/\s+/g, '_')}_${dateStr()}.html`;
  return { html, filename };
}

/** Generate classroom report as printable HTML. */
export async function generateClassroomReportHtml(
  env: Env,
  teacherId: string,
  classroomId: string
): Promise<{ html: string; filename: string }> {
  const report = await generateClassroomReport(env, teacherId, classroomId);
  const teacherName = await getTeacherName(env, teacherId);
  const branding = (await getBranding(env, teacherId)) ?? {};
  branding.teacher_name = teacherName;

  const html = renderClassroomReportHtml(report, { branding });
  const filename = `classroom_report_${report.classroom.name.replace(/\s+/g, '_')}_${dateStr()}.html`;
  return { html, filename };
}

// ---------- HTML renderers ----------

function renderStudentReportHtml(report: StudentReport, opts: ReportHtmlOptions): string {
  const b = opts.branding ?? {};
  const primary = b.primary_color ?? '#CCFF00';
  const logo = b.logo_url
    ? `<img src="${escapeHtml(b.logo_url)}" alt="Logo" style="height:48px;max-width:180px;object-fit:contain;" />`
    : `<div style="font-weight:800;font-size:24px;color:${primary};">${escapeHtml(b.teacher_name ?? 'Teacher')}</div>`;

  const scoreRows = [
    ['TOEFL iBT', report.progress.ibt_latest_score],
    ['TOEFL ITP', report.progress.itp_latest_score],
    ['IELTS Band', report.progress.ielts_latest_band],
    ['TOEIC', report.progress.toeic_latest_score],
  ]
    .map(
      ([label, score]) => `
      <tr>
        <td>${escapeHtml(label as string)}</td>
        <td style="text-align:right;font-weight:600;">${score === null ? '—' : score}</td>
      </tr>`
    )
    .join('');

  const weaknessRows = report.weaknesses.length
    ? report.weaknesses
        .map(
          (w) => `
        <tr>
          <td>${escapeHtml(w.area)}</td>
          <td style="text-align:right;">${w.score}</td>
          <td>${escapeHtml(w.recommendation)}</td>
        </tr>`
        )
        .join('')
    : '<tr><td colspan="3" style="color:#666;">No significant weaknesses detected.</td></tr>';

  const activityRows = report.recent_activity.length
    ? report.recent_activity
        .map(
          (a) => `
        <tr>
          <td>${escapeHtml(new Date(a.date).toLocaleDateString('id-ID'))}</td>
          <td>${escapeHtml(a.event)}</td>
          <td>${escapeHtml(a.platform)}</td>
        </tr>`
        )
        .join('')
    : '<tr><td colspan="3" style="color:#666;">No recent activity.</td></tr>';

  const oseeFooter = b.hide_osee_branding
    ? ''
    : `<div style="margin-top:32px;padding-top:12px;border-top:1px solid #eee;font-size:11px;color:#666;">
         Powered by <strong>OSEE.co.id</strong> — Official ETS Test Center since 2014 · <a href="https://osee.co.id">Book Official Test</a>
       </div>`;

  return `<!DOCTYPE html>
<html lang="id"><head><meta charset="utf-8" />
<title>Student Report — ${escapeHtml(report.student.name)}</title>
<style>
  @page { size: A4; margin: 18mm; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; color: #1a1a1a; margin: 0; padding: 24px; max-width: 800px; margin: 0 auto; }
  h1 { font-size: 22px; margin: 0 0 4px; }
  h2 { font-size: 14px; margin: 24px 0 8px; padding-bottom: 4px; border-bottom: 2px solid ${primary}; }
  .header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; }
  .meta { font-size: 12px; color: #555; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; margin-bottom: 8px; }
  th, td { padding: 8px 10px; text-align: left; border-bottom: 1px solid #eee; }
  th { background: #f8f8f8; font-weight: 600; font-size: 11px; text-transform: uppercase; letter-spacing: 0.04em; }
  .badge { display: inline-block; padding: 3px 10px; background: ${primary}; color: #000; border-radius: 999px; font-size: 11px; font-weight: 600; }
  @media print { body { padding: 0; } }
</style></head>
<body>
  <div class="header">
    <div>${logo}</div>
    <div style="text-align:right;">
      <div class="meta">Dibuat oleh: ${escapeHtml(b.teacher_name ?? 'Teacher')}</div>
      <div class="meta">${new Date(report.generated_at).toLocaleString('id-ID')}</div>
    </div>
  </div>
  <h1>Student Report</h1>
  <div class="meta" style="margin-bottom:8px;">
    <strong>${escapeHtml(report.student.name)}</strong> · ${escapeHtml(report.student.email)}<br/>
    Target: ${escapeHtml(report.student.target_exam ?? '—')} · Level: ${escapeHtml(report.student.current_level ?? '—')}
  </div>

  <h2>Latest Scores</h2>
  <table><thead><tr><th>Exam</th><th style="text-align:right;">Score</th></tr></thead>
  <tbody>${scoreRows}</tbody></table>
  <div class="meta" style="margin-top:6px;">EduBot streak: <strong>${report.progress.edubot_streak_days}</strong> days · Total practice: <strong>${report.progress.total_practice_count}</strong></div>

  <h2>Weakness Analysis</h2>
  <table><thead><tr><th>Area</th><th style="text-align:right;">Score</th><th>Recommendation</th></tr></thead>
  <tbody>${weaknessRows}</tbody></table>

  <h2>Recent Activity</h2>
  <table><thead><tr><th>Date</th><th>Event</th><th>Platform</th></tr></thead>
  <tbody>${activityRows}</tbody></table>

  ${oseeFooter}
</body></html>`;
}

function renderClassroomReportHtml(report: ClassroomReport, opts: ReportHtmlOptions): string {
  const b = opts.branding ?? {};
  const primary = b.primary_color ?? '#CCFF00';
  const logo = b.logo_url
    ? `<img src="${escapeHtml(b.logo_url)}" alt="Logo" style="height:48px;max-width:180px;object-fit:contain;" />`
    : `<div style="font-weight:800;font-size:24px;color:${primary};">${escapeHtml(b.teacher_name ?? 'Teacher')}</div>`;

  const studentRows = report.students.length
    ? report.students
        .map(
          (s) => `
        <tr>
          <td>${escapeHtml(s.name)}</td>
          <td style="text-align:right;">${s.latest_scores.ibt ?? '—'}</td>
          <td style="text-align:right;">${s.latest_scores.itp ?? '—'}</td>
          <td style="text-align:right;">${s.latest_scores.ielts ?? '—'}</td>
          <td style="text-align:right;">${s.latest_scores.toeic ?? '—'}</td>
          <td style="text-align:right;">${s.practice_count}</td>
        </tr>`
        )
        .join('')
    : '<tr><td colspan="6" style="color:#666;">No students enrolled.</td></tr>';

  const oseeFooter = b.hide_osee_branding
    ? ''
    : `<div style="margin-top:32px;padding-top:12px;border-top:1px solid #eee;font-size:11px;color:#666;">
         Powered by <strong>OSEE.co.id</strong> — Official ETS Test Center since 2014
       </div>`;

  const weaknessBadges = report.summary.common_weaknesses.length
    ? report.summary.common_weaknesses.map((w) => `<span class="badge">${escapeHtml(w)}</span>`).join(' ')
    : '<span style="color:#666;">None detected</span>';

  return `<!DOCTYPE html>
<html lang="id"><head><meta charset="utf-8" />
<title>Classroom Report — ${escapeHtml(report.classroom.name)}</title>
<style>
  @page { size: A4; margin: 18mm; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; color: #1a1a1a; margin: 0; padding: 24px; max-width: 900px; margin: 0 auto; }
  h1 { font-size: 22px; margin: 0 0 4px; }
  h2 { font-size: 14px; margin: 24px 0 8px; padding-bottom: 4px; border-bottom: 2px solid ${primary}; }
  .header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; }
  .meta { font-size: 12px; color: #555; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; margin-bottom: 8px; }
  th, td { padding: 8px 10px; text-align: left; border-bottom: 1px solid #eee; }
  th { background: #f8f8f8; font-weight: 600; font-size: 11px; text-transform: uppercase; letter-spacing: 0.04em; }
  .badge { display: inline-block; padding: 3px 10px; background: ${primary}; color: #000; border-radius: 999px; font-size: 11px; font-weight: 600; margin-right: 4px; }
  .stat { display: inline-block; padding: 10px 14px; background: #f8f8f8; border-radius: 8px; margin-right: 8px; }
  .stat-num { font-size: 20px; font-weight: 700; }
  .stat-label { font-size: 11px; color: #666; text-transform: uppercase; letter-spacing: 0.04em; }
  @media print { body { padding: 0; } }
</style></head>
<body>
  <div class="header">
    <div>${logo}</div>
    <div style="text-align:right;">
      <div class="meta">Dibuat oleh: ${escapeHtml(b.teacher_name ?? 'Teacher')}</div>
      <div class="meta">${new Date(report.generated_at).toLocaleString('id-ID')}</div>
    </div>
  </div>
  <h1>Classroom Report</h1>
  <div class="meta" style="margin-bottom:12px;">${escapeHtml(report.classroom.name)}</div>

  <h2>Summary</h2>
  <div>
    <div class="stat"><div class="stat-num">${report.summary.total_students}</div><div class="stat-label">Total Students</div></div>
    <div class="stat"><div class="stat-num">${report.summary.active_students}</div><div class="stat-label">Active</div></div>
    <div class="stat"><div class="stat-num">${report.summary.avg_progress}</div><div class="stat-label">Avg Score</div></div>
  </div>
  <div style="margin-top:12px;"><strong>Common Weaknesses:</strong> ${weaknessBadges}</div>

  <h2>Student Scores</h2>
  <table><thead><tr>
    <th>Student</th><th style="text-align:right;">iBT</th><th style="text-align:right;">ITP</th>
    <th style="text-align:right;">IELTS</th><th style="text-align:right;">TOEIC</th>
    <th style="text-align:right;">Practice #</th>
  </tr></thead><tbody>${studentRows}</tbody></table>

  ${oseeFooter}
</body></html>`;
}

// ---------- HTML utilities ----------

function escapeHtml(s: string): string {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function dateStr(): string {
  return new Date().toISOString().slice(0, 10);
}