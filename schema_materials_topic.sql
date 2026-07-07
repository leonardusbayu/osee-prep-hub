-- Add topic + tags columns to exam_questions
ALTER TABLE exam_questions ADD COLUMN IF NOT EXISTS topic TEXT;
ALTER TABLE exam_questions ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_questions_topic ON exam_questions(topic);
CREATE INDEX IF NOT EXISTS idx_questions_tags ON exam_questions USING GIN(tags);

-- Backfill topic from part + exam_type
UPDATE exam_questions SET topic = 'Photo Description' WHERE exam_type = 'TOEIC' AND part = '1' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Question-Response' WHERE exam_type = 'TOEIC' AND part = '2' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Conversations' WHERE exam_type = 'TOEIC' AND part = '3' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Talks' WHERE exam_type = 'TOEIC' AND part = '4' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Grammar: Incomplete Sentences' WHERE exam_type = 'TOEIC' AND part = '5' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Text Completion' WHERE exam_type = 'TOEIC' AND part = '6' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Reading Comprehension' WHERE exam_type = 'TOEIC' AND part = '7' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Speaking: Read Aloud' WHERE exam_type = 'TOEIC' AND part LIKE 'S1' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Speaking: Read Aloud' WHERE exam_type = 'TOEIC' AND part LIKE 'S2' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Speaking: Describe Picture' WHERE exam_type = 'TOEIC' AND part LIKE 'S3' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Speaking: Describe Picture' WHERE exam_type = 'TOEIC' AND part LIKE 'S4' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Speaking: Respond to Questions' WHERE exam_type = 'TOEIC' AND part LIKE 'S5' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Speaking: Respond to Questions' WHERE exam_type = 'TOEIC' AND part LIKE 'S6' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Speaking: Respond to Information' WHERE exam_type = 'TOEIC' AND part LIKE 'S7' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Speaking: Respond to Information' WHERE exam_type = 'TOEIC' AND part LIKE 'S8' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Speaking: Express Opinion' WHERE exam_type = 'TOEIC' AND part LIKE 'S9' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Speaking: Express Opinion' WHERE exam_type = 'TOEIC' AND part LIKE 'S10' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Speaking: Express Opinion' WHERE exam_type = 'TOEIC' AND part LIKE 'S11' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Writing: Picture Sentence' WHERE exam_type = 'TOEIC' AND part LIKE 'W%' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Reading' WHERE exam_type = 'IELTS' AND product_line = 'reading' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Listening' WHERE exam_type = 'IELTS' AND product_line = 'listening' AND topic IS NULL;
UPDATE exam_questions SET topic = 'Writing' WHERE exam_type = 'IELTS' AND product_line = 'writing' AND topic IS NULL;

-- Backfill tags from skill_tags (copy skill_tags into tags if tags is empty)
UPDATE exam_questions SET tags = skill_tags WHERE tags = '{}' AND skill_tags IS NOT NULL;