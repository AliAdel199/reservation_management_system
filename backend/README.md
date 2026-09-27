# Reservation Management API

Dart Shelf API for the government expense/reservation system. Setup and run steps are in the root [README](../README.md).

## Integration tests

The tests in `test/` run the real request pipeline against a **separate** PostgreSQL database whose name must end with `_test` (the suite refuses to run otherwise).

One-time setup:

```bash
psql <server-url>/postgres -c "CREATE DATABASE reservation_management_test"
psql <server-url>/reservation_management_test -f ../deploy/sql/001_customer_database_setup.sql
```

Run:

```bash
dart test
```

The database URL is `TEST_DATABASE_URL` if set, otherwise `DATABASE_URL` from `.env` with `_test` appended to the database name.
