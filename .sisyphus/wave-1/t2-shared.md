# T2 Shared-file Fragment

## schema.sql additions

Append at the end of schema.sql (or after the `syllabus_items` table, ~line 200):

```sql
-- ============================================================
-- Syllabus collaborators — Task 2 (Wave 1)
-- ============================================================
CREATE TABLE IF NOT EXISTS syllabus_collaborators (
  syllabus_id UUID NOT NULL REFERENCES syllabi(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'editor' CHECK (role IN ('owner', 'editor', 'viewer')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (syllabus_id, user_id)
);

CREATE INDEX idx_syllabus_collaborators_user ON syllabus_collaborators(user_id);

ALTER TABLE syllabus_collaborators ENABLE ROW LEVEL SECURITY;

-- Collaborators can see who else is on the syllabus.
-- Only the syllabus owner (via worker API) can add/remove — RLS denies direct inserts.
CREATE POLICY collaborators_select_self ON syllabus_collaborators
  FOR SELECT USING (true);

-- Enable Supabase Realtime on syllabus_collaborators + syllabus_items.
-- Run in Supabase SQL editor (not part of schema.sql idempotent apply):
--   ALTER PUBLICATION supabase_realtime ADD TABLE syllabus_items;
--   ALTER PUBLICATION supabase_realtime ADD TABLE syllabus_collaborators;
```

## flutter/pubspec.yaml additions

Add under `dependencies:`:

```yaml
  # Real-time collaboration — Task 2 (Wave 1)
  y_supabase: ^0.3.0
  yjs: ^0.3.0
```

## worker/src/types.ts

No Env additions needed — T2 uses existing SUPABASE_URL + SUPABASE_SERVICE_KEY.

## worker/src/index.ts route registration

Already added by orchestrator (inline):
```typescript
import { realtimeRoutes } from './routes/realtime';
// ...
app.route('/api', realtimeRoutes);
```