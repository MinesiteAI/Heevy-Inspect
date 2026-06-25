# Heevy Inspect v2 — TestFlight & launch checklist

## TestFlight build

1. Bump `version` in `pubspec.yaml` (e.g. `1.1.0+2`).
2. `flutter build ipa --release` with production Supabase env.
3. Upload via Xcode Organizer or `xcrun altool`.
4. Add internal testers; verify entitlement + four pillars on a provisioned org.

## E2E QA script

1. Sign up / sign in → entitlement gate passes.
2. **Quick capture** — photo + notes → WR number shown; optional WO toggle.
3. **My captures** — detail screen, signed photos, Field guide context.
4. **Inspections** — open template, submit PM → appears in My PM results.
5. **PM defect** — mark defective → offered WO create.
6. **Work orders** — list, detail, create from blank; upgrade CTAs on detail.
7. **Field guide** — ask about idler; open from capture/WO with context.
8. Sign out / deleted account → Back to sign in works.

## Analytics funnel (local counters)

`InspectAnalytics` tracks: `first_capture`, `capture_create_wo`, `first_wo_created`, `field_chat_message`, `upgrade_click`, `quick_capture_open`.

## App Store privacy

- Data linked to user: email, field captures, PM submissions, work orders, chat messages.
- Photos stored in private Supabase bucket; served via signed URLs only.
- No third-party ad tracking. AI chat uses org-scoped user records when `GEMINI_API_KEY` is set.
- Privacy policy: https://openminerals.ai/privacy

## Universal links

`public/.well-known/apple-app-site-association` includes `/capture/*` paths for Heevy Inspect (`com.minesiteai.heevyInspect`). Replace `REPLACE_WITH_APPLE_TEAM_ID` before production.
