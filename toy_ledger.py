accounts = {"CASH": 0, "CUST-A": 0, "CUST-B": 0}

def post_entry(accounts, postings):
    if len(postings) < 2:
        raise ValueError("an entry must have at least 2 postings")

    for posting in postings:

        if posting["account"] not in accounts:
            raise ValueError("unknown account")

        if posting["amount"] <= 0:
            raise ValueError("amount must be greater than zero")

        if posting["direction"] not in ["debit", "credit"]:
            raise ValueError("direction must be debit or credit")

    total_debits = 0
    total_credits = 0

    for posting in postings:
        if posting["direction"] == "debit":
            total_debits += posting["amount"]
        else:
            total_credits += posting["amount"]

    if total_debits != total_credits:
        raise ValueError(
            f"unbalanced entry: debits {total_debits}, credits {total_credits}"
        )

    # TODO 4 comes here
    for posting in postings:
        if posting["direction"] == "debit":
            accounts[posting["account"]] += posting["amount"]
        else:
            accounts[posting["account"]] -= posting["amount"]

# ---- try it ----
post_entry(accounts, [
    {"account": "CASH",   "direction": "debit",  "amount": 500_000},
    {"account": "CUST-A", "direction": "credit", "amount": 500_000},
])
print(accounts)

try:
    post_entry(accounts, [
        {"account": "CUST-A", "direction": "debit", "amount": 100_000},
        {"account": "CUST-B", "direction": "credit", "amount": 90_000},
    ])
except ValueError as e:
    print("Rejected:", e)

print(accounts)