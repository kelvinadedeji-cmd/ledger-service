
CREATE OR REPLACE FUNCTION check_journal_entry_balanced()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_entry_id BIGINT;
    v_debits BIGINT;
    v_credits BIGINT;
BEGIN
    -- Identify the journal entry affected by the posting.
    IF TG_OP = 'DELETE' THEN
        v_entry_id := OLD.entry_id;
    ELSE
        v_entry_id := NEW.entry_id;
    END IF;

    -- Calculate the total debit and credit amounts for that entry.
    SELECT
        COALESCE(SUM(amount_minor) FILTER (WHERE direction = 'debit'), 0),
        COALESCE(SUM(amount_minor) FILTER (WHERE direction = 'credit'), 0)
    INTO v_debits, v_credits
    FROM postings
    WHERE entry_id = v_entry_id;

    -- Reject the entry if the totals differ.
    IF v_debits <> v_credits THEN
        RAISE EXCEPTION
            'Unbalanced journal entry %: debits %, credits %',
            v_entry_id, v_debits, v_credits;
    END IF;

    RETURN NULL;
END;
$$;




DROP TRIGGER IF EXISTS journal_entry_balance_check
    ON journal_entries;

DROP TRIGGER IF EXISTS postings_balance_check
    ON postings;

CREATE CONSTRAINT TRIGGER journal_entry_balance_check
AFTER INSERT ON journal_entries
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_journal_entry_balanced();

CREATE CONSTRAINT TRIGGER postings_balance_check
AFTER INSERT ON postings
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_journal_entry_balanced();




CREATE OR REPLACE FUNCTION prevent_ledger_history_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'Ledger history is immutable: % is not allowed on table %',
        TG_OP, TG_TABLE_NAME;
END;
$$;


DROP TRIGGER IF EXISTS journal_entries_immutable
    ON journal_entries;

DROP TRIGGER IF EXISTS postings_immutable
    ON postings;

CREATE TRIGGER journal_entries_immutable
BEFORE UPDATE OR DELETE ON journal_entries
FOR EACH ROW
EXECUTE FUNCTION prevent_ledger_history_change();

CREATE TRIGGER postings_immutable
BEFORE UPDATE OR DELETE ON postings
FOR EACH ROW
EXECUTE FUNCTION prevent_ledger_history_change();
