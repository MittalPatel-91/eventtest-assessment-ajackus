# Event bookmarks API

## Endpoints

| Method | Path | Auth | Notes |
|--------|------|------|--------|
| `POST` | `/api/v1/events/:event_id/bookmarks` | Bearer JWT | Attendees only; **201** empty body on success |
| `DELETE` | `/api/v1/events/:event_id/bookmarks` | Bearer JWT | Attendees only; **204** on success |
| `GET` | `/api/v1/bookmarks` | Bearer JWT | Attendees only; list of bookmarked events |
| `GET` | `/api/v1/events/:id` | Optional | **`bookmarks_count`** only when the JWT belongs to the event organizer |

## curl examples

Set `BASE` (e.g. `http://localhost:3000`). Use real emails/passwords and ids from your DB or seeds.

### 1. Create a bookmark (attendee)

```bash
BASE="http://localhost:3000"

# Login as attendee
curl -s -X POST "$BASE/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"attendee@example.com","password":"your-password"}'
# Copy TOKEN from JSON.

TOKEN="<JWT>"
EVENT_ID=1

curl -s -i -X POST "$BASE/api/v1/events/$EVENT_ID/bookmarks" \
  -H "Authorization: Bearer $TOKEN"
```

**Expected:** `HTTP/1.1 201 Created` with an empty body.

### 2. Duplicate bookmark rejected

```bash
curl -s -i -X POST "$BASE/api/v1/events/$EVENT_ID/bookmarks" \
  -H "Authorization: Bearer $TOKEN"
```

**Expected:** `HTTP/1.1 422 Unprocessable Content` (or `422`) and body like:

```json
{"error":"Already bookmarked"}
```

### 3. Organizer sees `bookmarks_count` on event show

```bash
# Login as the event organizer
curl -s -X POST "$BASE/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"organizer@example.com","password":"your-password"}'

ORG_TOKEN="<JWT>"

curl -s "$BASE/api/v1/events/$EVENT_ID" \
  -H "Authorization: Bearer $ORG_TOKEN"
```

**Expected:** JSON includes `"bookmarks_count": <number>` when the token user owns the event. Attendees or unauthenticated clients do not receive `bookmarks_count`.

### 4. List my bookmarks

```bash
curl -s "$BASE/api/v1/bookmarks" \
  -H "Authorization: Bearer $TOKEN"
```

**Expected:** `200` and a JSON array of bookmarks with nested `event` fields.

## Tests

```bash
bundle exec rspec
```

All examples should pass, including `spec/requests/bookmarks_spec.rb` and `spec/models/bookmark_spec.rb`.
