-- Ledger Service & Integration Layer
-- Phase 1 schema draft, based on the project requirements.
-- Table definitions and declarative constraints only.
-- Deferred balancing and immutability triggers are the next session's work.
--
-- Money is stored as integer minor units (kobo), in NGN only.
--
-- Sign convention:
-- Customer deposit accounts are liabilities. A CREDIT increases a liability;
-- a DEBIT decreases it. A transfer from customer A to customer B debits A
-- and credits B.
-- For each account, a posting on its normal side increases its balance;
-- a posting on the opposite side decreases its balance.
--
-- Postings are the source of truth. account_balances is a maintained balance
-- cache and must be updated in the same database transaction as each posting.

CREATE TABLE accounts (
    account_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code                TEXT NOT NULL UNIQUE,
    name                TEXT NOT NULL,
    account_type        TEXT NOT NULL
                        CHECK (account_type IN (
                            'asset', 'liability', 'equity', 'income', 'expense'
                        )),
    normal_balance_side TEXT NOT NULL
                        CHECK (normal_balance_side IN ('debit', 'credit')),
    allow_negative      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT accounts_code_not_blank CHECK (length(trim(code)) > 0),
    CONSTRAINT accounts_name_not_blank CHECK (length(trim(name)) > 0)
);

CREATE TABLE journal_entries (
    entry_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reference         TEXT NOT NULL UNIQUE,
    description       TEXT,
    reverses_entry_id BIGINT UNIQUE
                      REFERENCES journal_entries(entry_id) ON DELETE RESTRICT,
    posted_at         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT journal_entries_reference_not_blank
        CHECK (length(trim(reference)) > 0),
    CONSTRAINT journal_entries_cannot_reverse_self
        CHECK (reverses_entry_id IS NULL OR reverses_entry_id <> entry_id)
);

CREATE TABLE postings (
    posting_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entry_id     BIGINT NOT NULL
                 REFERENCES journal_entries(entry_id) ON DELETE RESTRICT,
    account_id   BIGINT NOT NULL
                 REFERENCES accounts(account_id) ON DELETE RESTRICT,
    direction    TEXT NOT NULL CHECK (direction IN ('debit', 'credit')),
    amount_minor BIGINT NOT NULL CHECK (amount_minor > 0)
);

CREATE INDEX postings_entry_id_idx ON postings(entry_id);
CREATE INDEX postings_account_id_idx ON postings(account_id);
CREATE INDEX postings_account_entry_idx ON postings(account_id, entry_id);

CREATE TABLE account_balances (
    account_id    BIGINT PRIMARY KEY
                  REFERENCES accounts(account_id) ON DELETE RESTRICT,
    balance_minor BIGINT NOT NULL DEFAULT 0,
    version       BIGINT NOT NULL DEFAULT 0 CHECK (version >= 0),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE idempotency_keys (
    idempotency_key TEXT PRIMARY KEY,
    request_hash    TEXT NOT NULL,
    response_body   JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT idempotency_key_not_blank
        CHECK (length(trim(idempotency_key)) > 0),
    CONSTRAINT idempotency_request_hash_not_blank
        CHECK (length(trim(request_hash)) > 0)
);

-- The application must create an account and its initial zero balance in one
-- transaction.
--
-- Invariants requiring deferred constraint triggers and/or transaction-level
-- logic, intentionally reserved for the next session:
-- 1. Each journal entry has at least two postings.
-- 2. Each entry's total debits equal its total credits at COMMIT.
-- 3. Postings and journal entries cannot be UPDATEd or DELETEd.
-- 4. A non-negative account cannot finish a committed transaction below zero.
-- 5. Stored balances equal the sum of postings under each account's normal
--    balance convention, and ledger-wide debits equal credits.
--
-- Reversal policy: insert a new entry, swap every original posting's
-- direction, and set reverses_entry_id to the original. UNIQUE on
-- reverses_entry_id allows at most one reversal per original entry.
