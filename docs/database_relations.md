# Database Relational Integrity Documentation

# Overview
The Prisma schema has been completely overhauled to introduce explicit foreign key constraints across the PostgreSQL multi-schema architecture (`auth`, `trip`, `payment`, `pricing`, `kyc`). Previously, the schemas were flat, relying on unconstrained `String` UUIDs.

# Motivation
A production database cannot rely on application-level logic to maintain referential integrity. Without foreign keys, orphaned records (e.g. `Trip` pointing to a deleted `User`) corrupt the system state. By mapping explicit `@relation` fields, the database engine (PostgreSQL) now physically guarantees referential validity.

# Architecture
- **Multi-Schema Relationships**: Prisma preview feature `multiSchema` is leveraged to draw relations across schema boundaries (e.g., `payment.payments` -> `auth.users`).
- **Cascade Deletions**: 
  - `onDelete: Restrict` is heavily enforced on core financial and audit entities (Trips, Payments, Wallets, Payouts, Ratings). This prevents cascading data loss if an admin deletes a user.
  - `onDelete: Cascade` is applied only to ephemeral/sub-entities (e.g., `Session`, `TripEvent`, `GpsTrack`, `WalletTransaction`, `Document`).
  - `onDelete: SetNull` is used for `actorId` in `TripEvent` so the event history survives even if the actor is deleted.

# Components Modified
- **`schema.prisma`**: Added inverse relation arrays (e.g. `sessions Session[]`) to parent models like `User`, `Trip`, `Wallet`. Added direct `@relation` scalar mappings on all child models.

# Request Flow
This change is purely at the Data Access Layer (DAL) and RDBMS level. No API request flows are altered.

# Database Schema
Affects nearly all tables containing an `*Id` column:
- `auth.sessions`
- `trip.trips`, `trip.trip_events`, `trip.gps_tracks`, `trip.ratings`
- `payment.payments`, `payment.wallets`, `payment.wallet_transactions`, `payment.payouts`
- `kyc.driver_profiles`, `kyc.documents`

# Redis Usage
N/A

# API Contracts
N/A. However, Prisma queries can now natively use nested `include` blocks (e.g., `prisma.trip.findUnique({ include: { rider: true } })`).

# Configuration
No new environment variables required.

# Failure Handling
- **Constraint Violations**: Attempting to insert a `Trip` with a non-existent `riderId` will now throw a `PrismaClientKnownRequestError` (P2003: Foreign key constraint failed).

# Monitoring
- Watch for Prisma `P2003` errors in APM/logging. This indicates an application logic flaw attempting to map invalid relations.

# Security
Prevents ID spoofing at the database tier; you cannot map a payment to a fake trip ID.

# Testing
- Validation via `npx prisma validate` confirms topology correctness.
- `npx prisma db push` will enforce these constraints natively in PostgreSQL.

# Deployment
> [!WARNING]
> Before deploying this schema to production or staging, ensure there are no existing orphaned records. If existing rows violate the new foreign key constraints (e.g., a test trip without a valid user), `db push` will fail. You must clean the database or run manual SQL `DELETE` queries to scrub invalid relations.

# FAQ
**Q: Why do some relations use `Restrict` and others `Cascade`?**
A: We must never delete a user's `Trip` or `Payment` history simply because the `User` account was deleted. `Restrict` blocks user deletion until financial records are archived. Conversely, deleting a `User` should immediately delete their login `Session` via `Cascade`.

# Learning Notes
- **Concept Learned**: **Prisma Multi-Schema Relations**. Prisma elegantly handles cross-schema relations in Postgres using identical syntax to standard single-schema relations.
- **Architecture Best Practice**: Defer referential integrity to the database engine. Application logic is ephemeral and buggy; relational constraints are absolute.
