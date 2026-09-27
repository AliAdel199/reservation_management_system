# Reservation Management API

Dart Shelf API for the government expense/reservation system. Setup and run steps are in the root [README](../README.md).

## Database migrations

On start the API applies any new file in `database/migrations` (or `MIGRATIONS_DIR`) in order, each in its own transaction, after taking a `pg_dump` backup, and records it in `schema_migrations`. A failure stops startup. Existing databases without history are recorded as up to date through `017_deduplicate_roles`.

```bash
dart run bin/migrate.dart --status   # show pending migrations
dart run bin/migrate.dart            # apply them now
```

Never edit an applied migration; add a new numbered file. When adding one, also append it to `deploy/sql/001_customer_database_setup.sql` and its `schema_migrations` list (a test checks this).

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
