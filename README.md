# Invoice & Quotation App (Flutter + Firebase)

Application casri ah oo lagu maareeyo **Quotation (qiimeyn)** iyo **Invoice (biil)** — Firebase Firestore (cloud, sync, offline cache) iyo Firebase Auth login, PDF, lacag-bixinno, stock, iyo animation qurux badan.

## Sida loo ordo (Firebase setup)

1. Flutter **3.22 ama ka cusub** ku rakib (`flutter --version`).
2. [Firebase Console](https://console.firebase.google.com) → **Add project**.
   - **Build → Authentication → Sign-in method → Email/Password** → Enable
   - **Build → Firestore Database → Create database** (production mode)
   - **Firestore → Rules**: koobi garee waxa ku jira `firestore.rules` kadibna **Publish**
3. Terminal-ka:
   ```bash
   cd invoice_app
   flutter create --project-name invoice_app --platforms=android,ios .
   flutter pub get

   npm install -g firebase-tools      # haddii aadan horay u lahayn
   firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure              # dooro project-kaaga -> wuxuu abuurayaa lib/firebase_options.dart
   flutter run
   ```
4. Android: `android/app/build.gradle` (ama `build.gradle.kts`) ka dhig `minSdk = 23`.
5. App-ka: **Create account**.

> Haddii `flutter pub get` uu versions ka cabto, orod:
> `flutter pub add firebase_core firebase_auth cloud_firestore` — wuxuu soo qaadanayaa versions-ka ugu dambeeyay.

**Offline:** Firestore wuxuu xogta ku kaydiyaa telefoonka, sidaa darteed lists-ka iyo detail-ka waa la arki karaa internet la'aan. Waxyaabaha u baahan transaction (document cusub/lambar, payment, issue/cancel, convert) waxay u baahan yihiin internet.

## Qaab-dhismeedka (files kooban, code fudud)

```
lib/
  main.dart            App-ka, theme-ka (light/dark), bottom navigation
  db.dart              Firestore oo dhan: collections, xeerarka ganacsiga, transactions
  firebase_options.dart  (waxaa abuura `flutterfire configure`)
  models.dart          Customer, Product, Doc (quote/invoice), DocItem, Payment
  widgets.dart         Helpers (money, dates) + animated widgets
  pdf_service.dart     PDF A4 ah: print iyo share
  screens/
    dashboard.dart     KPI-yada, chart, invoices-kii ugu dambeeyay
    documents.dart     Quotes & Invoices: list, create/edit, detail, payments
    customers.dart     Macaamiisha: list, form, statement
    products.dart      Alaabta & adeegyada: list, form, stock
    login.dart         Sign in / Create account / Forgot password
    settings.dart      Account (sign out), shirkadda, currency, numbering, theme, delete all
firestore.rules        Security rules (user walba xogtiisa kaliya)
database/firestore-structure.md   Qaab-dhismeedka collections-ka
```

Quotation iyo Invoice waxay wadaagaan **isla screens iyo isla model** (`Doc`, `type = 'quote' | 'invoice'`) — sidaas darteed code-ku waa yar yahay oo fahamkiisu fudud yahay.

## Database (Firestore)

User walba xogtiisa waxay ku jirtaa `users/{uid}/...`:

| Collection | Ujeeddo |
|---|---|
| `customers` | Macaamiisha |
| `products` | Alaab / adeeg, qiimo, tax, stock |
| `quotations` | Qiimeynta (items-ku document-ka gudihiisa ayay ku jiraan) |
| `invoices` | Biilasha (items gudaha) |
| `payments` | Lacag-bixinnada (`invoice_id`) |
| `activity` | Taariikhda document kasta |
| `meta/settings` | Xogta shirkadda, currency, prefix, counters |

Lambarada, lacag-bixinta, stock-ga iyo convert-ka waxay ku dhacaan **Firestore transactions** si aysan xogtu u khaldamin. Indexes lagama baahna.

## Xaaladaha (scenarios) la daboolay

**Quotation:** `draft → sent → accepted / rejected → converted`
- Waxay si toos ah u noqotaa **expired** marka "valid until" dhaafo
- **Convert to invoice**: invoice cusub oo draft ah ayaa la abuuraa, labadooduna way isku xirmaan
- Quote la convert-gareeyay lama tirtiri karo, lamana beddeli karo
- Back to draft, duplicate, edit, delete

**Invoice:** `draft → sent → partial → paid` (ama `overdue` / `cancelled`)
- **Issue**: stock-ga alaabta "track stock" leh waa la jaraa — haddii stock ku filnayn waa la diidaa
- **Cancel**: stock-ga waa la celiyaa (kaliya haddii aysan lacag ku jirin)
- Lacag-bixin qayb-qayb ah (EVC Plus, eDahab, Cash, Bank...) — lagama bixin karo wax ka badan balance-ka
- Status-ka si toos ah ayuu isu beddelaa: partial / paid / overdue
- Payment la tirtiro → balance iyo status dib ayaa loo xisaabiyaa
- Edit waa la oggol yahay ilaa lacag laga bixiyo; stock-ga si sax ah ayaa dib loo xisaabiyaa
- Invoice draft ama cancelled ah kaliya ayaa la tirtiri karaa; haddii uu quote ka yimid, quote-ka wuxuu ku noqdaa "accepted"

**Kale:**
- Lambar otomaatig ah oo aan is-dhaafin: `QT-2026-0001`, `INV-2026-0001` (prefix waa la beddeli karaa)
- Discount line kasta (%) + discount guud (lacag ama %), tax line kasta
- Macmiil documents leh lama tirtiri karo; product la isticmaalay waa la **archive** gareeyaa
- Customer statement: billed / paid / balance
- Dashboard: outstanding, overdue, dakhliga bishan, quote win rate, chart 6 bilood, top customers
- PDF xirfad leh oo leh "PAID / OVERDUE" stamp — Print ama Share (WhatsApp, email...)
- Light / Dark mode, search, filter by status, pull-to-refresh, delete all

## Animations

Page transitions (fade + slide), staggered list entrance, count-up numbers, animated bar chart iyo progress bars, Hero animation (lambarka document-ka), animated status chips, AnimatedSize marka items lagu daro/laga saaro, swipe-to-delete.

## Beddel fudud

- **Midabka:** `main.dart` → `seedColor: Color(0xFF4F46E5)`
- **Payment methods:** `documents.dart` → `paymentMethods`
- **Default settings:** `db.dart` → `defaultSettings`
- **Login kale (Google, phone):** `screens/login.dart` iyo Firebase Console → Authentication
