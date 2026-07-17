# OSEE Prep Hub — API Reference

Base URL: `https://prep.osee.co.id/api`

## Authentication

All endpoints (except `/auth/register`, `/auth/login`, `/auth/verify`, `/pricing`, `/health`) require JWT.

Send via `Authorization: Bearer <token>` header or `osee_token` cookie (set on login).

## Endpoints by domain

### Auth (`/auth/*`)
| Method | Path | Description |
|---|---|---|
| POST | `/auth/register` | Register teacher/student/partner. Body: email, password, name, role, referral_code?, institution_name? |
| POST | `/auth/login` | Login. Body: email, password |
| POST | `/auth/verify` | Verify JWT. Returns {valid, user} |
| POST | `/auth/link-telegram` | Link Telegram to account. Body: telegram_id, osee_token? |
| POST | `/auth/refresh` | Refresh JWT |
| POST | `/auth/logout` | Clear cookie |

### Teacher (`/teacher/*`)
| Method | Path | Description |
|---|---|---|
| GET | `/teacher/dashboard` | Stats overview |
| POST | `/teacher/classrooms` | Create classroom |
| GET | `/teacher/classrooms` | List classrooms |
| GET | `/teacher/classrooms/:id` | Classroom detail with students |
| GET | `/teacher/classrooms/:id/students` | List students only |
| POST | `/teacher/classrooms/:id/students` | Add students by email |
| GET | `/teacher/referral-code` | Get referral code + usage stats |
| POST | `/teacher/syllabi` | Create syllabus |
| GET | `/teacher/syllabi` | List syllabi |
| GET | `/teacher/syllabi/:id` | Get syllabus + items |
| PUT | `/teacher/syllabi/:id/items` | Batch save items |
| POST | `/teacher/syllabi/:id/items` | Add single item |
| DELETE | `/teacher/syllabi/:id/items/:itemId` | Delete item |
| GET | `/teacher/students/:id/report` | Student report JSON |
| GET | `/teacher/students/:id/report/html` | Printable student report HTML |
| GET | `/teacher/classrooms/:id/report` | Classroom report JSON |
| GET | `/teacher/classrooms/:id/report/html` | Printable classroom report HTML |
| GET | `/teacher/pricing` | Pricing for role |

### Commission (`/teacher/commission/*`)
| Method | Path | Description |
|---|---|---|
| GET | `/teacher/commission/dashboard` | Earnings summary |
| GET | `/teacher/commission/recent` | Recent entries |
| POST | `/teacher/commission/payout` | Request payout. Body: amount, method |
| GET | `/teacher/commission/payouts` | Payout history |

### Student (`/student/*`)
| Method | Path | Description |
|---|---|---|
| GET | `/student/dashboard` | Dashboard data |
| GET | `/student/progress` | Progress across platforms |
| GET | `/student/syllabus` | Assigned syllabi |
| POST | `/student/syllabus/:itemId/start` | Mark item started |
| POST | `/student/syllabus/:itemId/complete` | Mark item completed |
| GET | `/student/readiness` | Readiness gauge |
| GET | `/student/cross-exam-map` | Cross-exam equivalency |
| GET | `/student/book-test` | Book test CTA |
| POST | `/student/classrooms/join` | Join via code |
| GET | `/student/classrooms` | Enrolled classrooms |

### AI (`/ai/*`)
| Method | Path | Description |
|---|---|---|
| POST | `/ai/grade-writing` | Grade essay (GPT-4o-mini + RAG) |
| POST | `/ai/grade-speaking` | Evaluate speaking (EduBot bridge) |
| GET | `/ai/grading/:id` | Get grading result |
| GET | `/ai/grading/history` | Grading history |
| POST | `/ai/grading/process` | Process pending (cron) |
| POST | `/ai/generate-material` | Generate material (RAG) |
| GET | `/ai/generation/:id` | Poll generation status |
| POST | `/ai/rag-search` | Vector search KB |
| POST | `/ai/rag/upload` | Upload to KB |
| GET | `/ai/quota` | Quota status |

### Video (`/videos/*`)
| Method | Path | Description |
|---|---|---|
| GET | `/videos/courses` | List courses |
| GET | `/videos/courses/:id` | Course + lessons |
| GET | `/videos/lessons/:id` | Lesson detail |
| POST | `/videos/lessons/:id/progress` | Track progress |
| POST | `/videos/lessons/:id/complete` | Record completion + quiz |
| POST | `/videos/admin/courses` | Admin: create course |
| PUT | `/videos/admin/courses/:id` | Admin: update course |
| POST | `/videos/admin/lessons` | Admin: create lesson |
| PUT | `/videos/admin/lessons/:id` | Admin: update lesson |

### Classes (`/classes/*`)
| Method | Path | Description |
|---|---|---|
| GET | `/classes/upcoming` | Upcoming classes |
| GET | `/classes/:id` | Class detail |
| POST | `/classes/:id/register` | Register interest |
| POST | `/classes/:id/remind` | Trigger reminder (admin) |
| POST | `/classes/cron/remind` | Cron: send reminders |
| POST | `/classes/admin/create` | Admin: create class |
| PUT | `/classes/admin/:id` | Admin: update (e.g. upload recording) |
| DELETE | `/classes/admin/:id` | Admin: cancel class |

### Platform (`/platform/*`)
| Method | Path | Description |
|---|---|---|
| GET | `/platform/materials` | Unified material list |
| GET | `/platform/scores` | Scores across platforms |

### Branding (`/branding/*`)
| Method | Path | Description |
|---|---|---|
| GET | `/branding` | Current branding + tier |
| PUT | `/branding` | Update branding |
| POST | `/branding/upgrade` | Upgrade to Pro/Institution |
| POST | `/branding/cancel` | Cancel subscription |

### Orders (`/orders/*`)
| Method | Path | Description |
|---|---|---|
| POST | `/orders` | Create order |
| GET | `/orders` | List orders |
| GET | `/orders/:id` | Order detail |
| POST | `/orders/:id/cancel` | Cancel pending order |
| POST | `/orders/:id/pay` | Initiate TriPay payment |
| POST | `/orders/webhook/tripay` | TriPay webhook callback |

### Ambassador (`/ambassador/*`)
| Method | Path | Description |
|---|---|---|
| GET | `/ambassador/dashboard` | Ambassador stats |
| GET | `/ambassador/proposal` | Printable proposal HTML |

### Admin (`/admin/*`)
| Method | Path | Description |
|---|---|---|
| GET | `/admin/stats` | Quick stats |
| GET | `/admin/analytics` | Full analytics |
| GET | `/admin/users` | List users (?role= filter) |
| GET | `/admin/teachers` | List teachers with stats |
| GET | `/admin/students` | List students with progress |
| GET | `/admin/pricing` | List pricing |
| POST | `/admin/pricing` | Set price |
| DELETE | `/admin/pricing/:itemType/:role` | Deactivate pricing |
| GET | `/admin/commission` | Commission summary cross-teacher |
| GET | `/admin/commission-rates` | List rates |
| POST | `/admin/commission-rates` | Update rate |
| GET | `/admin/ambassadors` | List ambassadors |
| POST | `/admin/ambassadors/promote` | Promote teacher to ambassador |
| GET | `/admin/knowledge-base/documents` | List KB docs (?category=&active=) |
| POST | `/admin/knowledge-base/upload` | Upload KB doc |
| POST | `/admin/knowledge-base/:id/embed` | Trigger embedding |

### External (EduBot bridge — internal secret) (`/external/*`)
| Method | Path | Description |
|---|---|---|
| POST | `/external/verify-student` | Verify Telegram user |
| POST | `/external/student-progress` | Receive progress from EduBot |
| GET | `/external/teacher-syllabus/:teacher_id` | Get syllabus topics |
| GET | `/external/student-deep-links/:student_id` | Get platform deep-links |

### Webhook (`/webhook/*`) — X-Webhook-Secret header
| Method | Path | Description |
|---|---|---|
| POST | `/webhook/ibt` | iBT practice events |
| POST | `/webhook/itp` | ITP practice events |
| POST | `/webhook/ielts` | IELTS events |
| POST | `/webhook/toeic` | TOEIC events |
| POST | `/webhook/booking` | Official booking events |
| POST | `/webhook/edubot` | EduBot events |

### Other
| Method | Path | Description |
|---|---|---|
| GET | `/health` | Health check |
| GET | `/pricing` | Public pricing (no auth) |
| POST | `/vouchers/validate` | Validate voucher code |
| POST | `/vouchers/redeem` | Redeem voucher |
| POST | `/upload/video` | Upload video to R2 |
| POST | `/upload/audio` | Upload audio to R2 |

## Error format

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message"
  }
}
```

Common codes: `UNAUTHORIZED`, `FORBIDDEN`, `NOT_FOUND`, `BAD_REQUEST`, `INVALID_INPUT`, `QUOTA_EXCEEDED`, `INTERNAL_ERROR`.