import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Syllabus assignment service — connects syllabi to classrooms and/or
 * individual students for personalized learning paths.
 *
 * Two assignment modes:
 *  - Classroom assignment: set syllabi.classroom_id (existing column) — all
 *    enrolled students see it.
 *  - Per-student assignment: insert into student_syllabus_assignments — only
 *    that one student sees it. Enables personalized syllabi.
 */

export interface Assignment {
  id: string;
  syllabus_id: string;
  student_id: string;
  student_name: string;
  student_email: string;
  assigned_by: string;
  assigned_at: string;
  is_active: boolean;
  notes: string | null;
}

/** Assign a syllabus to a single student. */
export async function assignSyllabusToStudent(
  env: Env,
  syllabusId: string,
  studentId: string,
  assignedBy: string,
  notes?: string
): Promise<{ id: string; syllabus_id: string; student_id: string }> {
  const supabase = getSupabase(env);

  // Verify the syllabus belongs to the calling teacher
  const { data: syllabus, error: sErr } = await supabase
    .from('syllabi')
    .select('teacher_id')
    .eq('id', syllabusId)
    .maybeSingle();
  if (sErr || !syllabus) {
    throw new Error('Syllabus not found');
  }
  if ((syllabus as Record<string, unknown>).teacher_id !== assignedBy) {
    throw new Error('Not your syllabus');
  }

  // Verify the student exists + is a student
  const { data: student, error: stErr } = await supabase
    .from('unified_profiles')
    .select('id, role')
    .eq('id', studentId)
    .maybeSingle();
  if (stErr || !student) {
    throw new Error('Student not found');
  }
  if ((student as Record<string, unknown>).role !== 'student') {
    throw new Error('Target user is not a student');
  }

  // Upsert the assignment (unique constraint on syllabus_id + student_id)
  const { data, error } = await supabase
    .from('student_syllabus_assignments')
    .upsert(
      {
        syllabus_id: syllabusId,
        student_id: studentId,
        assigned_by: assignedBy,
        notes: notes ?? null,
        is_active: true,
      },
      { onConflict: 'syllabus_id,student_id' }
    )
    .select()
    .single();

  if (error || !data) {
    throw new Error(`Assignment failed: ${error?.message ?? 'unknown'}`);
  }
  return {
    id: (data as Record<string, unknown>).id as string,
    syllabus_id: syllabusId,
    student_id: studentId,
  };
}

/** Assign a syllabus to an entire classroom (sets classroom_id on syllabus). */
export async function assignSyllabusToClassroom(
  env: Env,
  syllabusId: string,
  classroomId: string,
  teacherId: string
): Promise<{ syllabus_id: string; classroom_id: string; enrolled_count: number }> {
  const supabase = getSupabase(env);

  // Verify syllabus ownership
  const { data: syllabus, error: sErr } = await supabase
    .from('syllabi')
    .select('teacher_id')
    .eq('id', syllabusId)
    .maybeSingle();
  if (sErr || !syllabus) {
    throw new Error('Syllabus not found');
  }
  if ((syllabus as Record<string, unknown>).teacher_id !== teacherId) {
    throw new Error('Not your syllabus');
  }

  // Verify classroom ownership
  const { data: classroom, error: cErr } = await supabase
    .from('classrooms')
    .select('id, teacher_id')
    .eq('id', classroomId)
    .maybeSingle();
  if (cErr || !classroom) {
    throw new Error('Classroom not found');
  }
  if ((classroom as Record<string, unknown>).teacher_id !== teacherId) {
    throw new Error('Not your classroom');
  }

  // Set classroom_id on the syllabus
  const { error: updateErr } = await supabase
    .from('syllabi')
    .update({ classroom_id: classroomId })
    .eq('id', syllabusId);
  if (updateErr) {
    throw new Error(`Failed to link: ${updateErr.message}`);
  }

  // Count enrolled students
  const { count } = await supabase
    .from('classroom_enrollments')
    .select('id', { count: 'exact', head: true })
    .eq('classroom_id', classroomId)
    .eq('is_active', true);

  return {
    syllabus_id: syllabusId,
    classroom_id: classroomId,
    enrolled_count: count ?? 0,
  };
}

/** Unassign a syllabus from a student. */
export async function unassignSyllabusFromStudent(
  env: Env,
  syllabusId: string,
  studentId: string,
  teacherId: string
): Promise<void> {
  const supabase = getSupabase(env);

  // Verify ownership
  const { data: syllabus } = await supabase
    .from('syllabi')
    .select('teacher_id')
    .eq('id', syllabusId)
    .maybeSingle();
  if (!syllabus || (syllabus as Record<string, unknown>).teacher_id !== teacherId) {
    throw new Error('Not your syllabus');
  }

  const { error } = await supabase
    .from('student_syllabus_assignments')
    .delete()
    .eq('syllabus_id', syllabusId)
    .eq('student_id', studentId);
  if (error) {
    throw new Error(`Unassign failed: ${error.message}`);
  }
}

/** List all students assigned to a syllabus (both classroom + individual). */
export async function getSyllabusAssignments(
  env: Env,
  syllabusId: string,
  teacherId: string
): Promise<{ classroom_id: string | null; classroom_name: string | null; classroom_students: Array<{ id: string; name: string; email: string }>; individual_assignments: Assignment[] }> {
  const supabase = getSupabase(env);

  // Verify ownership
  const { data: syllabus } = await supabase
    .from('syllabi')
    .select('teacher_id, classroom_id')
    .eq('id', syllabusId)
    .maybeSingle();
  if (!syllabus || (syllabus as Record<string, unknown>).teacher_id !== teacherId) {
    throw new Error('Not your syllabus');
  }

  const classroomId = (syllabus as Record<string, unknown>).classroom_id as string | null;

  // Get classroom info + enrolled students if linked
  let classroomName: string | null = null;
  let classroomStudents: Array<{ id: string; name: string; email: string }> = [];
  if (classroomId) {
    const { data: classroom } = await supabase
      .from('classrooms')
      .select('name')
      .eq('id', classroomId)
      .maybeSingle();
    classroomName = classroom ? (classroom as Record<string, unknown>).name as string : null;

    const { data: enrollments } = await supabase
      .from('classroom_enrollments')
      .select(`
        student:unified_profiles!classroom_enrollments_student_id_fkey (id, display_name, email)
      `)
      .eq('classroom_id', classroomId)
      .eq('is_active', true);
    classroomStudents = ((enrollments ?? []) as Array<Record<string, unknown>>).map((e) => {
      const s = e.student as Record<string, unknown>;
      return { id: s.id as string, name: s.display_name as string, email: s.email as string };
    });
  }

  // Get individual assignments
  const { data: individual, error: iErr } = await supabase
    .from('student_syllabus_assignments')
    .select(`
      id, syllabus_id, student_id, assigned_by, assigned_at, is_active, notes,
      student:unified_profiles!student_syllabus_assignments_student_id_fkey (display_name, email)
    `)
    .eq('syllabus_id', syllabusId)
    .eq('is_active', true);
  if (iErr) {
    throw new Error(`Failed to fetch assignments: ${iErr.message}`);
  }

  const individualAssignments: Assignment[] = ((individual ?? []) as Array<Record<string, unknown>>).map((row) => {
    const student = row.student as Record<string, unknown>;
    return {
      id: row.id as string,
      syllabus_id: row.syllabus_id as string,
      student_id: row.student_id as string,
      student_name: (student.display_name as string) ?? '—',
      student_email: (student.email as string) ?? '—',
      assigned_by: row.assigned_by as string,
      assigned_at: row.assigned_at as string,
      is_active: row.is_active as boolean,
      notes: (row.notes as string) ?? null,
    };
  });

  return {
    classroom_id: classroomId,
    classroom_name: classroomName,
    classroom_students: classroomStudents,
    individual_assignments: individualAssignments,
  };
}

/**
 * Get all syllabi visible to a student:
 *  - Syllabi linked to their classrooms (classroom_id set + is_published)
 *  - Syllabi individually assigned to them via student_syllabus_assignments
 * Returns deduplicated list.
 */
export async function getStudentSyllabi(
  env: Env,
  studentId: string
): Promise<Array<{ id: string; name: string; description: string | null; target_exam: string | null; is_published: boolean; classroom_id: string | null; assigned_individually: boolean; syllabus_items: Array<Record<string, unknown>> }>> {
  const supabase = getSupabase(env);

  // 1. Classroom-linked syllabi
  const { data: enrollments } = await supabase
    .from('classroom_enrollments')
    .select('classroom_id')
    .eq('student_id', studentId)
    .eq('is_active', true);
  const classroomIds = ((enrollments ?? []) as Array<Record<string, unknown>>).map((e) => e.classroom_id as string);

  let classroomSyllabi: Array<Record<string, unknown>> = [];
  if (classroomIds.length > 0) {
    const { data: cs } = await supabase
      .from('syllabi')
      .select('*, syllabus_items(*)')
      .in('classroom_id', classroomIds)
      .eq('is_published', true);
    classroomSyllabi = (cs ?? []) as Array<Record<string, unknown>>;
  }

  // 2. Individually-assigned syllabi
  const { data: assignments } = await supabase
    .from('student_syllabus_assignments')
    .select('syllabus_id')
    .eq('student_id', studentId)
    .eq('is_active', true);
  const assignedSyllabusIds = ((assignments ?? []) as Array<Record<string, unknown>>).map((a) => a.syllabus_id as string);

  let individualSyllabi: Array<Record<string, unknown>> = [];
  if (assignedSyllabusIds.length > 0) {
    const { data: is } = await supabase
      .from('syllabi')
      .select('*, syllabus_items(*)')
      .in('id', assignedSyllabusIds);
    individualSyllabi = (is ?? []) as Array<Record<string, unknown>>;
  }

  // 3. Merge + dedupe (individual takes precedence)
  const seen = new Set<string>();
  const result: Array<{ id: string; name: string; description: string | null; target_exam: string | null; is_published: boolean; classroom_id: string | null; assigned_individually: boolean; syllabus_items: Array<Record<string, unknown>> }> = [];

  for (const s of individualSyllabi) {
    if (seen.has(s.id as string)) continue;
    seen.add(s.id as string);
    result.push({
      id: s.id as string,
      name: s.name as string,
      description: (s.description as string) ?? null,
      target_exam: (s.target_exam as string) ?? null,
      is_published: (s.is_published as boolean) ?? false,
      classroom_id: (s.classroom_id as string) ?? null,
      assigned_individually: true,
      syllabus_items: ((s.syllabus_items as Array<Record<string, unknown>>) ?? []).sort((a, b) => ((a.sort_order as number) ?? 0) - ((b.sort_order as number) ?? 0)),
    });
  }
  for (const s of classroomSyllabi) {
    if (seen.has(s.id as string)) continue;
    seen.add(s.id as string);
    result.push({
      id: s.id as string,
      name: s.name as string,
      description: (s.description as string) ?? null,
      target_exam: (s.target_exam as string) ?? null,
      is_published: (s.is_published as boolean) ?? false,
      classroom_id: (s.classroom_id as string) ?? null,
      assigned_individually: false,
      syllabus_items: ((s.syllabus_items as Array<Record<string, unknown>>) ?? []).sort((a, b) => ((a.sort_order as number) ?? 0) - ((b.sort_order as number) ?? 0)),
    });
  }

  return result;
}