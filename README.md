# مقابل | Moqabel

Arabic, right-to-left barter marketplace built with Next.js, React and Supabase. Items are exchanged for items, without cash top-ups.

## Run locally

Requires Node.js 22 or newer.

```sh
npm ci
npm run dev
```

Open http://localhost:3000. Without Supabase environment variables, the application shows a clearly labeled, read-only demonstration catalog. It does not pretend to create accounts, send offers, or deliver goods.

## Deploy to Vercel

Import `ZainabQabajah/-Moqabel`. Select **Next.js**, root directory `./`, and the default build/output settings. No environment variables are required to deploy the demonstration. Once Supabase is configured, add the following Vercel environment variables and redeploy:

```env
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Never use the service-role or secret key in a `NEXT_PUBLIC_` variable.

## Enable real accounts and data

1. Create a Supabase project owned by the project owner.
2. Run `supabase/schema.sql` once on the **new, empty project** in SQL Editor. The migration creates tables, authorization policies, transaction functions, and the public product-image bucket.
3. In Authentication settings, enable email/password authentication and email confirmation. Set the Site URL and allowed redirect URL to the actual deployment URL; add `http://localhost:3000` for local development. Configure SMTP for production email delivery.
4. Copy `.env.example` to `.env.local` and fill in the project URL and publishable key. Add the same values in Vercel and redeploy.
5. Create two confirmed test accounts in different browsers. Test the end-to-end checklist below before inviting users.

## Implemented

- Responsive Arabic marketplace, category/city/search filters, sorting, details and saved items.
- Email/password signup and login, real image uploads, item listings and wanted categories.
- Deterministic reciprocal category matching, with same-city results ranked first. No fabricated AI/value/trust score.
- Offers, acceptance/decline/cancellation while pending; accepting reserves both items and declines conflicting pending offers in a database transaction.
- Participant-only chat, refreshed every six seconds while open.
- In-person handover: each participant gets their own random QR/text code; confirmation requires the other participant's code. Completion requires both confirmations. No built-in camera scanner; a phone camera can read the QR as text.
- Completion-only ratings, item reports and swap disputes. Disputes freeze the swap and require manual operator resolution.
- SQL row-level security and restricted RPCs. Public profiles contain only a display name and city. Clients never receive the other participant's handover code from the API.

## Validation

```sh
npm run test
npm run typecheck
npm run build
```

### Before real users: two-account integration checklist

The database script and real-user paths require verification against the owner's Supabase project; a local demo build alone does not verify them.

- Register A and B; confirm emails and sign in independently.
- A uploads electronics seeking books; B uploads books seeking electronics. Confirm the reciprocal match and favorites persistence across reloads.
- A sends an offer; B accepts. A third competing offer must not reserve the same item. Both listings become reserved.
- A and B can read/send chat; a third account cannot read the offer, its messages, or handover codes.
- Try null/wrong codes; confirmation must fail. A's confirmation alone cannot complete a swap. Both valid confirmations complete it.
- Only a completed swap allows a rating. Each user can rate once.
- A dispute must freeze completion, record the reporter, and retain item reservation.
- Review RLS using unauthenticated, unrelated authenticated, and participant sessions; validate upload size and MIME restrictions.

## Launch boundaries

This is a first MVP implementation, not a fully operated logistics service. No payments, delivery partner, insurance promise, identity verification, phone OTP, AI valuation, multi-party swaps, password recovery UI, admin moderation UI, or automated dispute resolution is activated. An operator must review reports in Supabase and establish support, retention, dispute resolution and local legal policies before public launch. Accepted swaps currently require manual operator intervention for cancellation. Public catalog loading is capped at 500 records; add pagination before scaling. Product illustrations use Unsplash URLs and the typeface loads from Google Fonts.

Production reference documentation: [Next.js on Vercel](https://vercel.com/docs/frameworks/full-stack/nextjs), [Supabase row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security).
