# Firestore structure

```
users/{uid}/
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
  activity/{id}     doc_type (quote|invoice), doc_id, action, created_at
  meta/settings     company_name, currency, prefixes, default days/terms, theme,
                    quote_next, invoice_next (number counters)
```

Quotation status: draft | sent | accepted | rejected | expired | converted
Invoice status:   draft | sent | partial | paid | overdue | cancelled

Dates are text `yyyy-MM-dd`. Only equality queries are used, so no composite indexes are needed.
Numbering, payments, stock and quote→invoice conversion run inside Firestore transactions.
