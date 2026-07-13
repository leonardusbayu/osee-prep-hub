import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Ambassador program service — Task 17.x.
 *
 * Manages ambassador recruitment, bonuses, and dashboard.
 */

export interface AmbassadorStats {
  is_ambassador: boolean;
  recruited_teachers: number;
  total_bonus_earned: number;
  this_month_bonus: number;
  downline_activity: number;
}

/** Get ambassador stats for a teacher. */
export async function getAmbassadorStats(env: Env, userId: string): Promise<AmbassadorStats> {
  const supabase = getSupabase(env);

  // Check if ambassador — query teacher_profiles.is_ambassador (not role, which doesn't have 'ambassador')
  const { data: teacherProfile } = await supabase
    .from('teacher_profiles')
    .select('is_ambassador')
    .eq('user_id', userId)
    .maybeSingle();

  const isAmbassador = Boolean((teacherProfile as Record<string, unknown> | null)?.is_ambassador);

  // Count recruited teachers (referred_by = userId)
  const { count: recruitedCount } = await supabase
    .from('unified_profiles')
    .select('id', { count: 'exact', head: true })
    .eq('referred_by', userId)
    .eq('role', 'teacher');

  // Sum ALL commission earned by this ambassador (no action filter — ambassador 2x is via multiplier)
  const { data: commissions } = await supabase
    .from('commission_ledger')
    .select('amount_idr, created_at')
    .eq('teacher_id', userId);

  const now = new Date();
  const thisMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  let totalBonus = 0;
  let thisMonthBonus = 0;
  for (const c of commissions ?? []) {
    const amount = (c as Record<string, unknown>).amount_idr as number;
    const created = new Date((c as Record<string, unknown>).created_at as string);
    totalBonus += amount;
    if (created >= thisMonthStart) thisMonthBonus += amount;
  }

  return {
    is_ambassador: isAmbassador,
    recruited_teachers: recruitedCount ?? 0,
    total_bonus_earned: totalBonus,
    this_month_bonus: thisMonthBonus,
    downline_activity: recruitedCount ?? 0,
  };
}

/**
 * Generate the OSEE Teacher Proposal document as printable HTML — Task 17.3.
 *
 * This is the document ambassadors share with prospective teachers to pitch
 * the OSEE Partner Program. Renders the proposal template from Appendix C
 * of the blueprint, personalized with the ambassador's referral code.
 */
export async function generateProposalHtml(
  env: Env,
  ambassadorId: string
): Promise<{ html: string; filename: string }> {
  const supabase = getSupabase(env);

  // Get ambassador profile + referral code
  const { data: profile } = await supabase
    .from('unified_profiles')
    .select('id, display_name, email')
    .eq('id', ambassadorId)
    .maybeSingle();
  if (!profile) throw new Error('Ambassador not found');
  const p = profile as Record<string, unknown>;

  const { data: teacherProfile } = await supabase
    .from('teacher_profiles')
    .select('referral_code')
    .eq('user_id', ambassadorId)
    .maybeSingle();
  const referralCode = (teacherProfile as Record<string, unknown> | null)?.referral_code as string | null;

  const ambassadorName = (p.display_name as string) ?? 'OSEE Ambassador';
  const webappUrl = env.WEBAPP_URL || 'https://prep.osee.co.id';
  const registrationUrl = referralCode ? `${webappUrl}/r/${referralCode}` : `${webappUrl}/register`;

  const html = `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8" />
<title>OSEE Teacher Partner Program — Proposal</title>
<style>
  @page { size: A4; margin: 18mm; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; color: #1a1a1a; max-width: 800px; margin: 0 auto; padding: 32px; line-height: 1.6; }
  h1 { font-size: 28px; color: #16a34a; margin: 0 0 4px; }
  h2 { font-size: 16px; margin: 24px 0 8px; padding-bottom: 4px; border-bottom: 2px solid #CCFF00; }
  .header { text-align: center; padding: 24px 0; border-bottom: 3px solid #CCFF00; margin-bottom: 24px; }
  .header .logo { font-size: 32px; font-weight: 900; color: #16a34a; letter-spacing: -0.02em; }
  .header .tagline { font-size: 13px; color: #666; margin-top: 4px; }
  ul { padding-left: 20px; }
  li { margin-bottom: 6px; }
  .benefit-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin: 16px 0; }
  .benefit-card { padding: 14px; background: #f8faf8; border-radius: 8px; border-left: 4px solid #16a34a; }
  .benefit-card strong { color: #16a34a; }
  .earnings { background: #fefce8; padding: 16px; border-radius: 8px; margin: 12px 0; }
  .earnings h3 { margin: 0 0 8px; color: #ca8a04; }
  .cta { text-align: center; background: #16a34a; color: white; padding: 20px; border-radius: 12px; margin: 24px 0; }
  .cta a { color: white; font-weight: bold; text-decoration: underline; }
  .contact { font-size: 13px; color: #666; text-align: center; margin-top: 32px; padding-top: 16px; border-top: 1px solid #eee; }
  .ambassador { background: #eff6ff; padding: 12px; border-radius: 8px; font-size: 13px; margin: 16px 0; }
  @media print { body { padding: 0; } }
</style></head>
<body>
  <div class="header">
    <div class="logo">OSEE</div>
    <div class="tagline">Official ETS Test Center · Indonesia · Since 2014</div>
  </div>

  <h1>OSEE Teacher Partner Program</h1>
  <p style="font-size: 18px; color: #666;">"AI tools + income for English teachers in Indonesia"</p>

  <div class="ambassador">
    <strong>Shared by:</strong> ${escapeHtml(ambassadorName)}<br/>
    <strong>Referral code:</strong> ${escapeHtml(referralCode ?? '—')}<br/>
    <strong>Register:</strong> ${escapeHtml(registrationUrl)}
  </div>

  <h2>What You Get (FREE)</h2>
  <div class="benefit-grid">
    <div class="benefit-card"><strong>✓ AI Writing Grader</strong><br/>Grade 50 essays in 4 minutes, not 10 hours.</div>
    <div class="benefit-card"><strong>✓ AI Material Generator</strong><br/>Worksheets, quizzes, passages — in seconds.</div>
    <div class="benefit-card"><strong>✓ AI Speaking Evaluator</strong><br/>Students record, AI scores pronunciation + fluency.</div>
    <div class="benefit-card"><strong>✓ Syllabus Builder</strong><br/>Drag-and-drop. AI co-pilot suggests modules.</div>
    <div class="benefit-card"><strong>✓ Student Management</strong><br/>Track progress across all practice platforms.</div>
    <div class="benefit-card"><strong>✓ Printable Reports</strong><br/>Branded with your name. PDF-ready.</div>
    <div class="benefit-card"><strong>✓ Classroom Analytics</strong><br/>Weakness heatmap. Effectiveness metrics.</div>
    <div class="benefit-card"><strong>✓ Cross-Exam Support</strong><br/>TOEFL iBT, IELTS, TOEIC, ITP — in one portal.</div>
    <div class="benefit-card"><strong>✓ Tutor Bot</strong><br/>AI chat tutor in Telegram for your students.</div>
    <div class="benefit-card"><strong>✓ Live Classes</strong><br/>Free Zoom classes, shared via Tutor Bot.</div>
    <div class="benefit-card"><strong>✓ Video Library</strong><br/>Growing course library (50+ videos planned).</div>
    <div class="benefit-card"><strong>✓ Your Referral Code</strong><br/>Bring students, earn commission.</div>
  </div>

  <h2>What You Earn</h2>
  <div class="earnings">
    <h3>Commission per student action:</h3>
    <ul>
      <li><strong>Rp 10,000</strong> per student who completes their first practice test</li>
      <li><strong>Rp 50,000</strong> per student who books an official test at OSEE</li>
      <li><strong>Rp 15,000/month</strong> per student on EduBot premium (recurring!)</li>
      <li><strong>Rp 25,000</strong> per student who buys a practice package</li>
    </ul>
    <p><strong>Example:</strong> 30 students → <strong>Rp 500k–1.5juta / month</strong>, passively.</p>
  </div>

  <h2>Earn More AI Credits</h2>
  <ul>
    <li>+5 generation credits per student who registers via your code</li>
    <li>+5 generation credits per student who completes a test</li>
    <li>+10 generation credits per student who books an official test</li>
    <li>Or upgrade to <strong>Pro (Rp 50k/month)</strong> for unlimited everything.</li>
  </ul>

  <h2>Why OSEE?</h2>
  <ul>
    <li>Official ETS Test Center since 2014 — trusted by IIEF and ITC.</li>
    <li>5 practice platforms (TOEFL iBT, IELTS, TOEIC, ITP + AI Tutor Bot).</li>
    <li>AI trained on Indonesian-accented English.</li>
    <li>Materials validated for quality.</li>
    <li>Works on low-end Android with slow internet.</li>
  </ul>

  <h2>How to Start (2 minutes)</h2>
  <ol>
    <li>Register at <strong>${escapeHtml(registrationUrl)}</strong></li>
    <li>Create a classroom.</li>
    <li>Share your referral code with students.</li>
    <li>Build your syllabus (AI can help generate materials).</li>
    <li>Track progress + earn commission.</li>
  </ol>

  <div class="cta">
    <div style="font-size: 20px; font-weight: bold; margin-bottom: 8px;">Ready to start?</div>
    <div>Register free at <a href="${escapeHtml(registrationUrl)}">${escapeHtml(registrationUrl)}</a></div>
    <div style="margin-top: 8px; font-size: 13px;">Or contact ${escapeHtml((p.email as string) ?? '')} for a 15-min walkthrough.</div>
  </div>

  <div class="contact">
    OSEE · prep.osee.co.id · osee.co.id<br/>
    Powered by OSEE Education Hub — Official ETS Test Center since 2014
  </div>
</body></html>`;

  const filename = `osee_teacher_proposal_${ambassadorName.replace(/\s+/g, '_').toLowerCase()}.html`;
  return { html, filename };
}

function escapeHtml(s: string): string {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}