# Firestore structure

All users share one company. Access is controlled per user in `members`.

```
members/{uid}       email, role (admin|staff), active (bool), perms {key: true}, theme, created_at

company/main/
  customers/{id}    name, name_lower, phone, email, address, notes, created_at
  products/{id}     name, description, unit, price, tax_rate, track_stock (bool), stock, is_active (bool), created_at
  quotations/{id}   number, customer_id, customer_name/phone/email/address (copy),
                    date, due_date, status, discount_type, discount_value,
                    subtotal, tax_total, discount_total, total, paid,
                    notes, terms, link_id, stock_applied,
                    items: [ {product_id, description, qty, unit_price, discount_percent, tax_rate, line_total} ],
                    product_ids: [..], created_at, updated_at
  invoices/{id}     same fields as quotations
  payments/{id}     invoice_id, amount, date, method, reference, notes, created_at
  activity/{id}     doc_type (quote|invoice|customer|product|settings|member|data), doc_id,
                    action, label, by_uid, by_email, created_at
  meta/settings     company_name, currency, prefixes, default days/terms, migrated,
                    quote_next, invoice_next (number counters)

users/{uid}/...     old per-user data (read only); copied into company/main once for the admin
```

## Roles and privileges

- The email in `AppDb.adminEmail` (and in `firestore.rules`) becomes **admin** on first sign in.
- Every other new account is **staff, not approved** and sees nothing until the admin approves it.
- Admins have every privilege and open **Settings → Admin panel** (users + every action).
- Staff privileges (`perms`): `quotes_create`, `quotes_edit`, `quotes_delete`, `invoices_create`,
  `invoices_edit`, `invoices_delete`, `payments_add`, `payments_delete`, `customers`, `products`,
  `settings`, `delete_all`. Any approved user can view company data.
- The app checks privileges for a clear message; `firestore.rules` enforces them on the server.
- The action log can only be added to, never changed or deleted.

Quotation status: draft | sent | accepted | rejected | expired | converted
Invoice status:   draft | sent | partial | paid | overdue | cancelled

Dates are text `yyyy-MM-dd`. Only equality queries (plus one `orderBy created_at` on activity) are used, so no composite indexes are needed.
Numbering, payments, stock and quote→invoice conversion run inside Firestore transactions.
