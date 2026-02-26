# Phase 1 Foundation (UIUC Sublease)

## Data model overview

- `profiles` extends `auth.users` for dual-tier auth (`student` vs `resident`) and verification state.
- `listings` belongs to one lessor profile and enforces:
  - max 3 month lease window (`<= 92` days),
  - UIUC dorm address blocking,
  - break-focused categorization.
- `transactions` is the escrow ledger between one listing, lessor, and sublessee with Stripe IDs.
- `conversations`, `conversation_participants`, and `messages` model secure in-app chat.

## Relationship summary

- `auth.users (1) -> (1) profiles`
- `profiles (1) -> (N) listings`
- `listings (1) -> (N) transactions`
- `profiles (1) -> (N) transactions` as `lessor_id`
- `profiles (1) -> (N) transactions` as `sublessee_id`
- `listings (1) -> (N) conversations`
- `conversations (1) -> (N) messages`
- `conversations (1) -> (N) conversation_participants`
- `profiles (1) -> (N) conversation_participants`

See full SQL in `supabase/phase1_schema.sql`.
