# Code review — top issues

Prioritized by business impact (security, fraud, and data loss).

---

## 1. Global order access and cancellation (IDOR)

**`app/controllers/api/v1/orders_controller.rb:5-24, 21-47, 80-88` · Security**

**Severity:** Critical

**Description:** Order listing uses `Order.all`, and show/cancel use `Order.find` with no scope to `current_user`. Any authenticated caller can read every order (including confirmation numbers and payment references) and cancel other users’ pending or confirmed orders. This exposes PII and financial identifiers and allows direct revenue and operational damage.

**Recommend fix:** Scope all queries to the buyer: `current_user.orders` for index; `current_user.orders.find(params[:id])` for show and cancel. Add policy objects (Pundit / Action Policy) if organizers or admins need different rules.

**Proof (curl):** Requires API running and at least two users with orders from different buyers (e.g. after `db:seed`). Set `BASE` to the app URL (e.g. `http://localhost:3000`).

```bash
BASE="http://localhost:3000"

# 1) Login as user B; copy JWT from response
curl -s -X POST "$BASE/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"user_b@example.com","password":"their-password"}'
```

**Expected:** HTTP `200`, body includes `token` and `user` (e.g. `"id": 2`).

**Expected:** HTTP `200`, body includes `token` and `user` (e.g. `"id": 2`).

**Expected:** HTTP `200`, body includes `token` and `user` (e.g. `"id": 2`).

```bash
TOKEN="<paste JWT>"

# 2) List orders — vulnerable app returns every order, not only B’s
curl -s -w "\nHTTP_CODE:%{http_code}\n" \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE/api/v1/orders"

# 3) Read another user’s order by ID (replace 1 with an order not owned by B)
curl -s -w "\nHTTP_CODE:%{http_code}\n" \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE/api/v1/orders/1"
```

**Expected proving vulnerability:** HTTP `200` on `GET /orders` with a **JSON array** containing orders beyond user B’s own; on `GET /orders/:id`, HTTP `200` with full order detail (`confirmation_number`, `event`, `items`, `payment`, etc.) for an order that belongs to another user.

---

## 2. No ownership checks on events and ticket tiers

**`app/controllers/api/v1/events_controller.rb:89-102` · `app/controllers/api/v1/ticket_tiers_controller.rb:23-47` · Security**

**Severity:** Critical

**Description:** Updates and deletes load `Event.find` and `TicketTier.find` without verifying the organizer. Any logged-in user can change or delete another user’s events and pricing tiers, causing defacement, wrongful cancellations (with attendee emails from model callbacks), and inventory tampering.

**Recommend fix:** Load through ownership: `current_user.events.find(params[:id])` and nested `event.ticket_tiers.find(params[:id])` after `current_user.events.find(params[:event_id])`. Enforce the same checks in a central policy layer.

---

## 3. SQL injection and unsafe ORDER on events index

**`app/controllers/api/v1/events_controller.rb:9-21` · Security**

**Severity:** Critical

**Description:** Search strings are interpolated into a `WHERE` clause, and `params[:sort_by]` is passed to `order()`, allowing crafted input to alter or break queries and potentially exfiltrate or corrupt data depending on the database and Active Record version.

**Recommend fix:** Use bound parameters for search: `where("title LIKE ? OR description LIKE ?", "%#{sanitize_sql_like(term)}%", ...)`. Replace free-text `sort_by` with a whitelist hash mapping safe user choices to fixed `ORDER BY` fragments (or `reorder` with only literal strings).

**Proof (curl):** `events#index` does not require auth. Use only local/dev environments you control.

```bash
BASE="http://localhost:3000"

# A) Search: single quote breaks interpolated LIKE — unsanitized SQL
curl -s -w "\nHTTP_CODE:%{http_code}\n" \
  "$BASE/api/v1/events?search=%27"
```

**Expected proving vulnerability:** HTTP **`500`** (typical) with `ActiveRecord::StatementInvalid` / `PG::SyntaxError` in logs or development JSON, showing user input was concatenated into the SQL string.

```bash
# B) sort_by: arbitrary fragment passed to order()
curl -s -w "\nHTTP_CODE:%{http_code}\n" \
  "$BASE/api/v1/events?sort_by=not_a_real_column_xyz"
```

**Expected proving vulnerability:** HTTP **`500`** with undefined column / invalid `ORDER BY`, or fragile or unexpected ordering — user-controlled `sort_by` is not a safe whitelist.

---

## 4. Privilege escalation on registration

**`app/controllers/api/v1/auth_controller.rb:34-36` · Security**

**Severity:** Critical

**Description:** `register_params` permits `:role`, so clients can set `admin` or `organizer` at signup. If the application trusts `user.role` for access control, attackers gain elevated privileges without admin approval.

**Recommend fix:** Remove `:role` from permitted params; set `role` to a default (e.g. `attendee`) in the controller or model. Expose role changes only through protected admin flows.

---

## 5. Dangerous mass assignment on tiers and events

**`app/controllers/api/v1/ticket_tiers_controller.rb:52-54` · `app/controllers/api/v1/events_controller.rb:107-109` · Security / Data integrity**

**Severity:** High

**Description:** Permitting `:sold_count` on ticket tiers allows manual manipulation of inventory and revenue fields. Permitting `:status` on events allows skipping intended workflows and forcing states such as `cancelled`, triggering side effects (e.g. bulk emails) without business rules.

**Recommend fix:** Drop `sold_count` from strong params; update sold counts only inside services or tier methods. Remove `status` from generic `event_params`; use explicit actions (e.g. publish/cancel) or a service that sets status with authorization and validations.

---

## 6. Orders built from tiers that do not belong to the event

**`app/controllers/api/v1/orders_controller.rb:49-63` · `app/models/order_item.rb` · Data integrity**

**Severity:** High

**Description:** The controller resolves tiers with `TicketTier.find` while the order is tied to `Event.find(params[:event_id])`, so line items can reference tiers from other events. Totals and inventory updates become inconsistent and enable abuse across events.

**Recommend fix:** Resolve tiers only through the event: `event.ticket_tiers.find(item_data[:ticket_tier_id])`. Add a model validation on `OrderItem` that `ticket_tier.event_id == order.event_id` (or validate via a nested build from `event`).

---

## 7. Weak database guarantees for relationships and money

**`db/schema.rb` (foreign keys, nullability, uniqueness) · Data integrity / Architecture**

**Severity:** Medium

**Description:** Foreign keys are not declared, important columns remain nullable, and `payments` has no unique constraint on `order_id` despite `Order has_one :payment`. Duplicate confirmation numbers are not prevented at the DB layer. Invalid or orphan rows can appear from bulk operations or bugs, and concurrency can still oversell tickets without locking or checks.

**Recommend fix:** Add foreign keys and `NOT NULL` on required FKs; unique index on `orders.confirmation_number` and on `payments.order_id`. Add check constraints where appropriate (e.g. `sold_count <= quantity`). Use transactions with row locks or optimistic locking in `reserve_tickets!` for concurrent sales.

---

## Severity legend

| Level    | Meaning |
|----------|---------|
| Critical | Exploitable at scale; confidentiality, integrity, or availability severely impacted |
| High     | Serious abuse or corruption likely without full DB compromise |
| Medium   | Important hardening; failure modes or edge cases that amplify other bugs |
