# Terminal session log (cleaned)

Condensed from `terminal_log.txt` (script capture, Apr 6 2026). ANSI escape sequences and line-noise removed; commands and outcomes preserved.

---

## Setup

### Environment

- **Project:** `eventtest-assessment-ajackus`
- **API base:** `BASE="http://localhost:3000"`
- **Rails:** 7.1.6 (Puma on `127.0.0.1:3000` / `[::1]:3000`)
- **Ruby:** 3.4.8 (arm64-darwin)

### Server

```bash
rails s
# => Booting Puma, … Listening on http://127.0.0.1:3000
```

### Seed users (from `db/seeds.rb`)

| Email | Role | Password (example) |
|-------|------|----------------------|
| `priya@eventnest.dev` | organizer | `password123` |
| `rahul@eventnest.dev` | organizer | `password123` |
| `ananya@example.com` | attendee | `password123` |
| `vikram@example.com` | attendee | `password123` |
| `sneha@example.com` | attendee | `password123` |

---

## Initial tests

### Orders controller spec

```bash
bundle exec rspec spec/controllers/orders_controller_spec.rb
```

**Result:** `5 examples, 0 failures`

### Full suite (after IDOR-related work, before bookmarks)

```bash
bundle exec rspec
```

**Result:** `31 examples, 0 failures`

---

## Bug proof (curl)

### 1. Login / auth (wrong or unknown user)

```bash
curl -s -X POST "$BASE/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"user_b@example.com","password":"their-password"}'
```

**Response:** `{"error":"No account found with that email"}` (401 path in auth flow)

### 2. Orders IDOR (vulnerable behavior — before fix)

With **no** `TOKEN` set (or invalid token):

```bash
curl -s -w "\nHTTP_CODE:%{http_code}\n" \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE/api/v1/orders"
```

**Response:** `{"error":"Unauthorized"}` + `HTTP_CODE:401`

After logging in as **attendee** (`ananya@example.com`) and setting `TOKEN` correctly, **before** the IDOR fix the server loaded **all** orders:

```text
Order Load … SELECT "orders".* FROM "orders" ORDER BY "orders"."created_at" DESC
```

**Response body (example):** JSON array with **four** orders (ids 1–4), including events not solely owned by the current user — demonstrating global listing.

### 3. SQL injection / unsafe search (`events#index`)

```bash
curl -s "$BASE/api/v1/events?search=%27"
```

**Server log:** `title LIKE '%'%' OR description LIKE '%'%'` → **500 Internal Server Error**

**`ActiveRecord::StatementInvalid`:** `PG::AmbiguousFunction: ERROR: operator is not unique: unknown % unknown`

---

## Fix proof

### IDOR fix (orders scoped to `current_user`)

- **Commit (example):** `80074f8` — *Fix IDOR … by scoping order resources to current_user*
- **Files:** `app/controllers/api/v1/orders_controller.rb`, `spec/controllers/orders_controller_spec.rb`, `REVIEW.md`
- **Push:** `git push origin main` → `2ce1322..80074f8  main -> main`

### After fix — orders index scoped by user

```bash
# Login as ananya@example.com, set TOKEN
curl -s -X GET "$BASE/api/v1/orders" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN"
```

**Server log (fixed):**

```text
Order Load … SELECT "orders".* FROM "orders" WHERE "orders"."user_id" = $1 ORDER BY …
```

**Response (example):** Only **two** orders for user id 3 (Ananya), e.g. ids `4` and `1` — no other users’ orders.

### Migrations + bookmarks

```bash
bin/rails db:migrate
bundle exec rspec
```

**Result:** `45 examples, 0 failures`

---

## Feature demo (bookmarks API)

### 1. Organizer cannot bookmark

**Login:** `priya@eventnest.dev` (organizer) → JWT

```bash
curl -s -i -X POST "$BASE/api/v1/events/1/bookmarks" \
  -H "Authorization: Bearer $TOKEN"
```

**Response:** `HTTP/1.1 403 Forbidden` — `{"error":"Forbidden"}`

### 2. Attendee bookmark — create

**Login:** `ananya@example.com` → JWT (attendee). Example event id **9** (after creating event as organizer in console / DB).

```bash
curl -s -i -X POST "$BASE/api/v1/events/9/bookmarks" \
  -H "Authorization: Bearer $TOKEN"
```

**Response:** `HTTP/1.1 201 Created` (empty body)

### 3. Duplicate bookmark

Repeat the same `POST` as above.

**Response:** `HTTP/1.1 422 Unprocessable Content` — `{"error":"Already bookmarked"}`

### 4. List bookmarks (attendee)

```bash
curl -s "$BASE/api/v1/bookmarks" \
  -H "Authorization: Bearer $TOKEN"
```

**Response (example):**

```json
[{"id":1,"bookmarked_at":"2026-04-06T17:40:25.543Z","event":{"id":9,"title":"Diwali Night Market 2024","venue":"Jawaharlal Nehru Stadium, Delhi","city":"Delhi","starts_at":"2026-02-06T17:39:21.052Z","ends_at":"2026-02-06T23:39:21.052Z"}}]
```

### 5. Organizer-only `bookmarks_count` on event show

```bash
curl -s "$BASE/api/v1/events/9" \
  -H "Authorization: Bearer $TOKEN"
```

When `TOKEN` is the **event owner** (Ananya for event 9), **response includes** `"bookmarks_count":1`. Other roles / no auth do not receive that field (per implementation).

### 6. `GET /bookmarks` as organizer (forbidden)

With Priya’s token:

**Response:** `403 Forbidden` — `{"error":"Forbidden"}`

---

## Final tests

```bash
bundle exec rspec
```

**Result:** `45 examples, 0 failures` (run time ~2.0–2.2s)

### Bookmark feature commit

- **Commit:** `9feb784` — *Added bookmark feature with APIs, DB level constraints, model validation and testcases*
- **Push:** `80074f8..9feb784  main -> main`

---

## Notes

- **Deprecation:** `secret_key_base` in `Rails.application.secrets` (Rails 7.2 removal planned).
- **Sidekiq:** connects to Redis during part of the test run.
- **Typos in session:** e.g. `priya@eventnest.devm` → “No account found”; malformed `curl` lines → `zsh: command not found` for `-H` or `TOKEN` — fixed by re-running complete commands.
