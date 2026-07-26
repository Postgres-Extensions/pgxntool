# pg_tle Version Support Matrix

This file documents pg_tle version boundaries that affect pgxntool's pg_tle support code. Each boundary represents a backward-incompatible API change.

## Version Ranges (pgxntool notation)

### 1.0.0-1.4.0
- **pg_tle versions:** 1.0.0 through 1.3.x
- **PostgreSQL support:** 11-17
- **API:** `pgtle.uninstall_extension(extname text)` present and unchanged since 1.0.0 (as is the `uninstall_extension(extname text, version text)` overload); no schema parameter on `install_extension()`
- **Features:** Basic extension management, custom data types, authentication hooks

### 1.4.0-1.5.0
- **pg_tle versions:** 1.4.0 through 1.4.x
- **PostgreSQL support:** 11-17
- **API:** No install/uninstall API change from the prior range - `uninstall_extension()` is unchanged and `install_extension()` still has no schema parameter. The 1.4.0 release instead added alignment/storage parameters to `pgtle.create_base_type()`
- **Features:** Custom alignment/storage, enhanced warnings

### 1.5.0+
- **pg_tle versions:** 1.5.0 and later (tested through 1.5.2)
- **PostgreSQL support:** 12-18 (dropped PG 11)
- **API:** BREAKING CHANGE - `pgtle.install_extension()` now requires schema parameter
- **Features:** Schema parameter support in installation

## Key API Changes by Version

**1.4.0:** No change to `install_extension()` or `uninstall_extension()`
- `pgtle.uninstall_extension(extname text)` has existed unchanged since pg_tle 1.0.0 (confirmed against the tagged source: `pg_tle--1.0.0.sql` already defines it, and `pg_tle--1.3.4--1.4.0.sql` makes no install/uninstall changes)
- What was added in 1.0.1-1.0.4 (still within this range) was a body-only change to the existing `uninstall_extension(extname text, version text)` overload (added default-version protection logic), not a new overload
- Added alignment/storage parameters to `pgtle.create_base_type()` (see Features above)

**1.5.0:** Changed `pgtle.install_extension()` signature
- Added required `schema` parameter
- Dropped PostgreSQL 11 support

## Version Notation

- `X.Y.Z+` - Works on pg_tle >= X.Y.Z
- `X.Y.Z-A.B.C` - Works on pg_tle >= X.Y.Z and < A.B.C

**Boundary conditions:**
- `1.5.0+` means >= 1.5.0 (includes 1.5.0)
- `1.4.0-1.5.0` means >= 1.4.0 and < 1.5.0 (excludes 1.5.0)
- `1.0.0-1.4.0` means >= 1.0.0 and < 1.4.0 (excludes 1.4.0)

## For Complete Details

- `pgtle.sh` (comments at top)
- https://github.com/aws/pg_tle
