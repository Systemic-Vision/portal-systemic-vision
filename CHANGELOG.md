# Changelog

All notable changes to the Links Admin Panel and its mobile API.

## 2026-10-14

- Rider app can record its own GPS trail during a trip (`POST /api/trips/[id]/rider-locations`, see `docs/api/trip-rider-locations.md`), with clock-skew correction and handling for proxy rides where the rider's phone isn't in the vehicle.
- Trip detail page shows the rider's trail and a coverage badge; admin views of rider locations are access-logged.
- Panic tracking pages include the rider's trail from before the alert was pressed.
- **Migration:** adds the `trip_rider_locations` table; apply in `links592db` before deploying.

## 2026-10-13

- Panic alerts stream the presser's GPS trail to the live tracking page (`POST /api/panic/[id]/locations`, see `docs/api/panic.md` and `docs/api/track.md`), accepted only while the alert is active.
- Panic SMS and tracking links use the origin of the incoming request.
- Cost-estimate zone classification and fare rules refined, with distance sanity checks; a standalone v2 pricing engine (`pricingtestv2.js`) added for testing.

## 2026-09-11

- Trip detail page shows more trip data and links coordinates to maps; dashboard trip metrics reworked.
- Driver subscription filtering refined.

## 2026-09-09

- Drivers can be filtered by subscription start and end dates.
- Driver `total_trips` is now counted from completed trips in the `trips` table.

## 2026-09-04

- Admins can add and manage notes on driver profiles.
- Incident evidence images open in a lightbox.

## 2026-09-03

- Analytics: new cancellation, rating, geography and matching sections.

## 2026-09-02

- Panic (SOS) button: `POST /api/panic` creates an incident and alert, fans out SMS via Twilio, and returns a public live tracking link (`/track/[token]`); admins get a realtime alert banner. See `docs/api/panic.md` and `docs/api/track.md`.
- **Config:** new `system_config` keys `panic_button_enabled`, `panic_support_numbers` and `panic_test_mode` (keep `PANIC_TEST_MODE=true` locally).

## 2026-09-01

- Dashboard "active riders" now counts riders with a trip request in the last two weeks.

## 2026-08-30

- Analytics overhaul: corrected calculations, new layout, and responsive charts; charts moved from Recharts to Nivo.
- Dashboard shows an estimated revenue metric and descriptions for each metric card.
- Trips page: fare summary cards, dates default to today, and a clear-filters button.
- Admin sidebar can be collapsed on desktop.

## 2026-08-13

- Colour moved onto semantic design tokens defined in `app/globals.css`, with migration tooling in `scripts/migration/` to verify classes and colour signatures.
- Brand colour switched from blue to the Links 592 orange.

## 2026-08-11

- Cancelling a trip returns the request to the pool through the `reopen_trip_request_after_cancel` RPC (same locking as accept); repeated cancels are idempotent and the rider gets a distinct `trip_cancelled_reopened` notification.

## 2026-07-03

- Driver filters for subscription expiry and recent trip activity.
- KPI recommendations and implementation plan added (`docs/kpi-recommendations.md`).

## 2026-06-15

- Consistent currency formatting across the admin via `formatCurrency`.
- Image lightbox component for viewing photos full screen.

## 2026-06-07

- Multi-stop trips: trip requests accept an ordered `dropoffs` array, stored as `trip_stops` (see `docs/api/trip-requests.md`). The trip status PATCH accepts `complete_stop_index` and completes the trip after the last stop. Admin pages show planned stops on the map and in Google Maps directions.

## 2026-06-04

- Status and type values are shown in human-readable form across admin lists.
- **Migration:** `20260528120000_trips_one_active_per_request.sql` allows only one active trip per trip request.

## 2026-05-24

- Admin driver list loads drivers in pages.
- Cost-estimate zone classification refined.

## 2026-05-20

- Central-zone fares changed to a flat rate.

## 2026-05-18

- Trip status PATCH accepts optional `completed_at`, `completed_latitude` and `completed_longitude`.
- Trips and trip requests pages keep their filters in the URL through per-page filter hooks.

## 2026-05-13

- Trips list, trip detail and recent trips show estimated and actual fares separately.

## 2026-05-12

- Trip requests from riders whose verification was rejected are refused.
- Actual fare is no longer overwritten by the trip status route.

## 2026-05-11

- Trip detail shows location history with timestamps, speeds and coordinates; active drivers map handles more location formats.
- Guyana time helpers added (`lib/guyana-time.ts`).
- **Config:** new `NEXT_PUBLIC_LOCATION_RECORDED_AT_AS_GUYANA_WALL` env var (see `.env.example`).

## 2026-05-07

- Incident reporting: apps can report incidents and admins can review and manage them.

## 2026-05-02

- Admins can send push notifications to selected riders.

## 2026-05-01

- Admins can send push notifications to drivers from the admin UI.
- Price estimates accept an optional drop-off location.

## 2026-04-30

- Agreement acceptances log and driver detail page improved.
- Agreement acceptance check on trip requests temporarily disabled.

## 2026-04-29

- Admins can manage the landmarks used for cost estimates.

## 2026-04-27

- Cost-estimation functions for the ride-hailing apps; clearer drop-off location error message.
- Riders page loads in pages with URL-backed search; trips page status cards include a total.

## 2026-04-26

- Riders can be filtered by ID card and profile photo status.
- Clearer "trip requests paused" notification text.
- Rider verification check on trip requests temporarily disabled.

## 2026-04-25

- Agreement acceptances log page in the admin.

## 2026-04-24

- Versioned driver and rider agreements: apps fetch the current agreement, record acceptance (stored as a generated PDF), and admins publish new versions under Settings.
- Agreement API routes made dynamic; `pdf-lib` excluded from bundling.

## 2026-04-23

- Admins can pause and resume trip requests from Settings; riders are notified when requests are paused.
- Trip route map resolves GPS points to addresses and draws the travelled path.

## 2026-04-22

- Trips page shows count cards per trip status.

## 2026-04-21

- Card/table view toggle on admin list pages.

## 2026-04-20

- Trips page date range filters.
- Cancelling a trip updates its trip request accordingly.
- More reliable FCM token lookup with batching and better error handling.

## 2026-04-18

- Trip requests page and date filters in the admin.
- Admins can manage a driver's subscription from the driver detail page.

## 2026-04-13

- Driver detail page shows subscription details more clearly.

## 2026-04-09

- Trip status API accepts the `arrived` status.

## 2026-04-06

- Push notification handling and logging improved; any authenticated user can call the notification broadcast endpoint.

## 2026-04-05

- Trip details show timezone-aware dates.
- Driver list filters kept in the URL.

## 2026-04-04

- Admins manage mobile app versions under Settings, including mandatory updates; the version check API validates per platform version and build.
- Admin notifications page for broadcasting messages to drivers or riders.
- **Breaking:** push notification API now sends directly to FCM tokens and no longer validates user role (see `docs/api/notifications-send.md`).

## 2026-04-02

- Version check API for the mobile apps.
- Admins can send push notifications to drivers.

## 2026-04-01

- Trip status update API (`PATCH /api/trips/[id]/status`).
- Payment transactions record a subscription start date.
- Riders no longer need an active subscription to request trips.

## 2026-03-31

- Dashboard and driver detail pages show more counts and navigation links.

## 2026-03-30

- Admins can send SMS; trip detail page added.

## 2026-03-27

- Driver push notification route simplified and error checks fixed.

## 2026-03-12

- Audit log page showing database inserts, updates and deletes, with filters by table, action and date.
- Security fixes for MMG and Firebase: no sensitive values in logs, fail-fast key checks, idempotent checkout, race-free webhook processing, and sanitised 500 responses.

## 2026-02-09

- Any authenticated user can create a trip request (role check removed).

## 2026-01-30

- `POST /api/mmg/confirm-payment` lets the app confirm an MMG payment and create the subscription (see `docs/api/mmg-confirm-payment.md`).

## 2026-01-28

- MMG subscription payments: checkout and webhook endpoints, encrypted tokens, and payment success and failure pages (see `docs/api/mmg-checkout.md`).
- Driver search improved.

## 2026-01-24

- Firebase Cloud Messaging support for push notifications.

## 2026-01-12

- Mobile API: login and trip request endpoints with validation and error handling; destination address is required (see `docs/api/auth-login.md` and `docs/api/trip-requests.md`).

## 2026-01-10

- Rider detail page; driver detail shows vehicle information.

## 2026-01-09

- Active drivers map on Google Maps.
- Driver management components and schema reworked.

## 2026-01-08

- Middleware and client-side auth redirect reworked.

## 2026-01-07

- Initial admin panel: Next.js with Supabase auth, dashboard, driver management and first analytics components.
