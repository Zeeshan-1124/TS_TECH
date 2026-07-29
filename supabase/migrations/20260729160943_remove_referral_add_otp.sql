/*
# Remove Referral System + Add OTP Authentication Table

## What This Migration Does

### Part 1 — Remove Referral System (Refer & Earn)
This completely removes the referral/refer-and-earn feature from the database.
All three referral tables are dropped along with their data.

Tables being DROPPED (data loss is intentional — user requested full removal):
1. `ReferralCredit` — stored wallet credits from referrals
2. `ReferralUse` — tracked each time a referral code was used
3. `ReferralCode` — stored each user's unique referral code

Foreign key columns on `Order` that referenced referral tables are also dropped:
- `Order.referralUses` relation
- `Order.referralCredits` relation

Foreign key columns on `User` that referenced referral tables are also dropped:
- `User.referralCode` relation
- `User.referralUses` relation
- `User.referralCredits` relation

### Part 2 — Add OTP Authentication Table
A new `OtpCode` table to support email-based OTP authentication.
When a user signs in or signs up, a 6-digit code is emailed to them via Resend.
The code is stored here with an expiry time, then verified and deleted on use.

New table:
- `OtpCode`
  - `id` (uuid, primary key)
  - `email` (text, the email address the OTP was sent to)
  - `code` (text, the 6-digit code, stored hashed with bcrypt for security)
  - `expires_at` (timestamptz, 10 minutes from creation)
  - `attempts` (int, tracks failed verification attempts, max 5)
  - `created_at` (timestamptz, default now)

### Security
- RLS enabled on `OtpCode`.
- CRUD policies scoped to `anon, authenticated` since OTP verification happens
  before the user is authenticated (the endpoint needs to read/verify codes
  without an existing session). The API route validates the code server-side
  and issues a JWT only on success.
*/

-- ──────────────────────────────────────────────────────
-- Part 1: Drop referral tables (in dependency order)
-- ──────────────────────────────────────────────────────

DROP TABLE IF EXISTS "ReferralCredit" CASCADE;
DROP TABLE IF EXISTS "ReferralUse" CASCADE;
DROP TABLE IF EXISTS "ReferralCode" CASCADE;

-- ──────────────────────────────────────────────────────
-- Part 2: Create OTP authentication table
-- ──────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS "OtpCode" (
    "id"          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "email"       TEXT NOT NULL,
    "code"        TEXT NOT NULL,
    "expires_at"  TIMESTAMPTZ NOT NULL,
    "attempts"    INTEGER NOT NULL DEFAULT 0,
    "created_at"  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast lookup by email
CREATE INDEX IF NOT EXISTS "OtpCode_email_idx" ON "OtpCode" ("email");
-- Index for cleanup of expired codes
CREATE INDEX IF NOT EXISTS "OtpCode_expires_at_idx" ON "OtpCode" ("expires_at");

ALTER TABLE "OtpCode" ENABLE ROW LEVEL SECURITY;

-- OTP verification happens before authentication, so we need anon access.
-- The API route validates codes server-side; these policies just allow
-- the server-side Prisma queries to work with the connection string.
DROP POLICY IF EXISTS "anon_all_otpcodes" ON "OtpCode";
CREATE POLICY "anon_all_otpcodes" ON "OtpCode" FOR SELECT
    TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_otpcodes" ON "OtpCode" FOR INSERT
    TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_otpcodes" ON "OtpCode" FOR UPDATE
    TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_otpcodes" ON "OtpCode" FOR DELETE
    TO anon, authenticated USING (true);