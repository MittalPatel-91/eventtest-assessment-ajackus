# EventNest API — Project summary

Rails 7 API-only event ticketing. This document summarizes setup, work completed on this fork, remaining risks, how to call the API, tests, and where to find session evidence.

The stock project readme was preserved as **`README_ORIGINAL.md`** (formerly `README.md`). Use **`README.md`** (this file) for the assessment-oriented summary; use **`README_ORIGINAL.md`** for Docker steps, full endpoint list, seed notes, and AI conversation tracking.

---

## Setup

**Requirements:** Ruby 3.4+ (see `Gemfile`), PostgreSQL, Bundler.

```bash
bundle install
rails db:create db:migrate db:seed
rails server   # http://localhost:3000
bundle exec rspec
```

**Docker:** See **`README_ORIGINAL.md`** for `docker-compose` and `docker-compose exec web rails db:create db:migrate db:seed`.

**Seed users:** All passwords `password123`. Organizers: `priya@eventnest.dev`, `rahul@eventnest.dev`. Attendees: `ananya@example.com`, `vikram@example.com`, `sneha@example.com`. Details in `db/seeds.rb`.

---

## Tasks completed

| Area | What was done |
|------|----------------|
| **Security review** | Documented top issues (authorization, IDOR, SQLi, mass assignment, data integrity) in `REVIEW.md`. |
| **IDOR fix (orders)** | `GET /orders`, `GET /orders/:id`, and `POST /orders/:id/cancel` scoped to `current_user.orders`. Covered by `spec/controllers/orders_controller_spec.rb`. |
| **Bookmarks** | `Bookmark` model, unique `(user_id, event_id)` at DB + validation; `POST/DELETE /api/v1/events/:event_id/bookmarks`; `GET /api/v1/bookmarks`; organizer-only `bookmarks_count` on `GET /api/v1/events/:id` when JWT matches event owner; attendees-only bookmark actions. Docs in `BOOKMARKS.md`. |

---

## Pending work (recommended approach)

Issues called out in `REVIEW.md` that are **not** fully addressed in code:

| Item | Approach |
|------|----------|
| **Events / ticket tiers — no ownership checks** | Load resources via `current_user.events` and nested `event.ticket_tiers`; add Pundit or Action Policy if roles expand. |
| **SQL injection / unsafe `ORDER` on `events#index`** | Bind parameters for search; whitelist `sort_by` to fixed fragments. |
| **Role on registration** | Remove `:role` from permitted params; default `attendee` in app code. |
| **Mass assignment (`sold_count`, `status`)** | Tighten strong params; use dedicated actions for publish/cancel. |
| **Orders — tiers must belong to event** | Resolve tiers with `event.ticket_tiers.find(...)`; validate `OrderItem` against `order.event`. |
| **DB constraints** | Foreign keys, `NOT NULL` on FKs, unique indexes where needed (e.g. `payments.order_id`). |

Prioritize by exposure: public `events#index` SQL issues and unscoped mutating controllers before deeper schema work.

---

## API usage (curl)

Set `BASE=http://localhost:3000`. Obtain a JWT:

```bash
curl -s -X POST "$BASE/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"ananya@example.com","password":"password123"}'
```

**Orders (scoped to current user):**

```bash
TOKEN="<jwt>"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/orders"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/orders/1"
```

**Bookmarks:** Attendees only for create/list/delete path; organizers see `bookmarks_count` on event show when the token user owns the event. Full examples and response expectations: **`BOOKMARKS.md`**.

**Core routes:** Auth, events, ticket tiers, orders — see **`README_ORIGINAL.md`** (section *API Endpoints*). Bookmarks routes are listed in `BOOKMARKS.md` and `config/routes.rb`.

---

## Tests

```bash
bundle exec rspec
```

Expected: all examples green (e.g. **45 examples, 0 failures** after bookmarks). Focused runs:

```bash
bundle exec rspec spec/controllers/orders_controller_spec.rb
bundle exec rspec spec/requests/bookmarks_spec.rb spec/models/bookmark_spec.rb
```

---

## References (logs & documentation)

| Asset | Purpose |
|-------|---------|
| **`README_ORIGINAL.md`** | Original project readme: Docker setup, seed data, full API endpoint list, AI conversation tracking (evaluation). |
| **`README.md`** | This summary (tasks, pending work, curl pointers, test commands, doc index). |
| **`TERMINAL_LOG.md`** | Cleaned session narrative: setup, tests, IDOR/SQLi proof, fix verification, bookmark demo, final `rspec`. |
| **`BOOKMARKS.md`** | Bookmark API curl examples and test command. |
| **`REVIEW.md`** | Prioritized security / integrity findings and fix guidance. |

**Screen recording:** If the evaluation asks for workflow evidence, use the recording as the primary capture; these files supplement with exact commands and outcomes.

---

## AI collaboration

Per **`README_ORIGINAL.md`**, git hooks may copy AI tool conversations into `.ai-conversations/` on commit. That process is unchanged by this summary document.
