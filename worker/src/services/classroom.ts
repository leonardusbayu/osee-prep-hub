import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Classroom service — create classrooms, generate join codes,
 * list teacher's classrooms, get classroom detail with enrolled students.
 *
 * Task 2.2: Classroom creation + join code generation
 * Task 2.4: Classroom enrollment system
 */

const JOIN_CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I, O, 0, 1
const JOIN_CODE_LENGTH = 6;

/** Generate a unique 6-char join code (collision-checked). */
export async function generateUniqueJoinCode(
  supabase: import('@supabase/supabase-js').SupabaseClient
): Promise<string> {
  for (let attempt = 0; attempt < 20; attempt++) {
    let code = '';
    for (let i = 0; i < JOIN_CODE_LENGTH; i++) {
      code += JOIN_CODE_CHARS[Math.floor(Math.random() * JOIN_CODE_CHARS.length)];
    }
    const { data } = await supabase
      .from('classrooms')
      .select('id')
      .eq('join_code', code)
      .maybeSingle();
    if (!data) return code;
  }
  throw new Error('Failed to generate unique join code after 20 attempts');
}

/** Create a new classroom for a teacher. Returns the created classroom. */
export async function createClassroom(
  env: Env,
  teacherId: string,
  input: { name: string; description?: string; target_exam?: string; max_students?: number }
): Promise<{ id: string; name: string; join_code: string; description: string | null; target_exam: string | null; max_students: number }> {
  const supabase = getSupabase(env);

  if (!input.name || input.name.trim().length === 0) {
    throw new Error('Classroom name required');
  }

  const joinCode = await generateUniqueJoinCode(supabase);

  const insertPayload: Record<string, unknown> = {
    teacher_id: teacherId,
    name: input.name.trim(),
    description: input.description ?? null,
    target_exam: input.target_exam ?? null,
    max_students: input.max_students ?? 50,
    join_code: joinCode,
    join_code_active: true,
    is_active: true,
  };

  const { data, error } = await supabase
    .from('classrooms')
    .insert(insertPayload)
    .select()
    .single();

  if (error || !data) {
    throw new Error(`Failed to create classroom: ${error?.message ?? 'unknown'}`);
  }

  return {
    id: data.id,
    name: data.name,
    join_code: data.join_code,
    description: data.description,
    target_exam: data.target_exam,
    max_students: data.max_students,
  };
}

/** List all classrooms owned by a teacher. */
export async function getClassroomsByTeacher(
  env: Env,
  teacherId: string
): Promise<Array<{ id: string; name: string; join_code: string; description: string | null; target_exam: string | null; is_active: boolean; max_students: number }>> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('classrooms')
    .select('id, name, join_code, description, target_exam, is_active, max_students')
    .eq('teacher_id', teacherId)
    .order('created_at', { ascending: false });

  if (error) {
    throw new Error(`Failed to list classrooms: ${error.message}`);
  }

  return (data ?? []) as Array<{
    id: string;
    name: string;
    join_code: string;
    description: string | null;
    target_exam: string | null;
    is_active: boolean;
    max_students: number;
  }>;
}

/** Get classroom detail with enrolled students. */
export async function getClassroomDetail(
  env: Env,
  teacherId: string,
  classroomId: string
): Promise<{
  classroom: Record<string, unknown>;
  students: Array<Record<string, unknown>>;
}> {
  const supabase = getSupabase(env);

  // Get classroom — must belong to teacher
  const { data: classroom, error: classroomError } = await supabase
    .from('classrooms')
    .select('*')
    .eq('id', classroomId)
    .eq('teacher_id', teacherId)
    .maybeSingle();

  if (classroomError || !classroom) {
    throw new Error('Classroom not found or not owned by teacher');
  }

  // Get enrolled students
  const { data: enrollments, error: enrollError } = await supabase
    .from('classroom_enrollments')
    .select(`
      id,
      enrolled_at,
      is_active,
      student:unified_profiles!classroom_enrollments_student_id_fkey (
        id, email, display_name, role, current_level, target_exam
      )
    `)
    .eq('classroom_id', classroomId)
    .eq('is_active', true);

  if (enrollError) {
    throw new Error(`Failed to fetch enrollments: ${enrollError.message}`);
  }

  return {
    classroom,
    students: (enrollments ?? []) as Array<Record<string, unknown>>,
  };
}

/** Enroll a student in a classroom via join code. */
export async function enrollStudentByJoinCode(
  env: Env,
  studentId: string,
  joinCode: string
): Promise<{ classroom_id: string; classroom_name: string }> {
  const supabase = getSupabase(env);

  // Find classroom by join code
  const { data: classroom, error: findError } = await supabase
    .from('classrooms')
    .select('id, name, teacher_id, is_active, join_code_active, max_students')
    .eq('join_code', joinCode.toUpperCase())
    .maybeSingle();

  if (findError || !classroom) {
    throw new Error('Invalid join code');
  }
  if (!classroom.is_active || !classroom.join_code_active) {
    throw new Error('Classroom is not accepting new students');
  }

  // Check if already enrolled
  const { data: existing } = await supabase
    .from('classroom_enrollments')
    .select('id')
    .eq('classroom_id', classroom.id)
    .eq('student_id', studentId)
    .maybeSingle();

  if (existing) {
    throw new Error('Already enrolled in this classroom');
  }

  // Check capacity
  const { count } = await supabase
    .from('classroom_enrollments')
    .select('id', { count: 'exact', head: true })
    .eq('classroom_id', classroom.id)
    .eq('is_active', true);

  if (count !== null && count >= classroom.max_students) {
    throw new Error('Classroom is full');
  }

  // Enroll
  const { error: enrollError } = await supabase.from('classroom_enrollments').insert({
    classroom_id: classroom.id,
    student_id: studentId,
    enrolled_via: 'join_code',
    is_active: true,
  });

  if (enrollError) {
    throw new Error(`Enrollment failed: ${enrollError.message}`);
  }

  return {
    classroom_id: classroom.id,
    classroom_name: classroom.name,
  };
}

/** List classrooms a student is enrolled in. */
export async function getStudentClassrooms(
  env: Env,
  studentId: string
): Promise<Array<{ id: string; name: string; teacher_name: string; target_exam: string | null }>> {
  const supabase = getSupabase(env);

  const { data, error } = await supabase
    .from('classroom_enrollments')
    .select(`
      classroom:classrooms!classroom_enrollments_classroom_id_fkey (
        id, name, target_exam,
        teacher:unified_profiles!classrooms_teacher_id_fkey (
          display_name
        )
      )
    `)
    .eq('student_id', studentId)
    .eq('is_active', true);

  if (error) {
    throw new Error(`Failed to fetch student classrooms: ${error.message}`);
  }

  return (data ?? []).map((row: Record<string, unknown>) => {
    const classroom = row.classroom as Record<string, unknown>;
    const teacher = classroom.teacher as Record<string, unknown>;
    return {
      id: classroom.id as string,
      name: classroom.name as string,
      teacher_name: teacher.display_name as string,
      target_exam: (classroom.target_exam as string) ?? null,
    };
  });
}