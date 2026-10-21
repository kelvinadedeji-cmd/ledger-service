import pytest
from toy_ledger import post_entry

def test_balanced_entry_accepted():
    accounts = {"CASH": 0, "CUST-A": 0}

    post_entry(accounts, [
        {"account": "CASH", "direction": "debit", "amount": 500_000},
        {"account": "CUST-A", "direction": "credit", "amount": 500_000},
    ])

    assert accounts["CASH"] == 500_000
    assert accounts["CUST-A"] == -500_000


def test_unbalanced_entry_rejected():
    accounts = {"CASH": 0, "CUST-A": 0}

    with pytest.raises(ValueError):
        post_entry(accounts, [
            {"account": "CASH", "direction": "debit", "amount": 100_000},
            {"account": "CUST-A", "direction": "credit", "amount": 90_000},
        ])


def test_fewer_than_two_postings_rejected():
    accounts = {"CASH": 0, "CUST-A": 0}

    with pytest.raises(ValueError):
        post_entry(accounts, [
            {"account": "CASH", "direction": "debit", "amount": 500_000},
        ])


def test_zero_or_negative_amount_rejected():
    accounts = {"CASH": 0, "CUST-A": 0}

    with pytest.raises(ValueError):
        post_entry(accounts, [
            {"account": "CASH", "direction": "debit", "amount": 0},
            {"account": "CUST-A", "direction": "credit", "amount": 0},
        ])

    with pytest.raises(ValueError):
        post_entry(accounts, [
            {"account": "CASH", "direction": "debit", "amount": -100},
            {"account": "CUST-A", "direction": "credit", "amount": 100},
        ])