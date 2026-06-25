# Heevy Inspect

Thin field-capture app for inspections and anomalies (lead-gen tier).

## Stack

- Flutter (iOS-first)
- Shared Supabase project with [minesite-io](https://github.com/MinesiteAI/minesite-io) and [minesite-ai-mobile](https://github.com/MinesiteAI/minesite-ai-mobile)

## Run

```bash
flutter pub get
flutter run -d "iPhone 17"
```

Optional env:

```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Edge functions (this repo)

Deploy to project `ribjmoizwcvowrbhbfri`:

```bash
supabase functions deploy mobile-submit-field-capture --project-ref ribjmoizwcvowrbhbfri
```

Backend pack / entitlement changes live in **minesite-io** migrations and `check-entitlement`.

## v1 scope

- Apply-only auth (no IAP)
- Quick capture → draft work request
- My captures history
- Optional PM templates when `allows_plant`
- Upgrade CTA → web Plant CMMS
