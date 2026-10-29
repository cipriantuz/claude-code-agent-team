---
name: ef-migration
disable-model-invocation: true
description: Trigger when user says "add migration", "modify schema", "update database", "create table with EF" — orchestrate full EF Core migration flow with safety gates
---

# EF Core Migration Orchestrator

## Steps (run in order, never skip)

### 1. Apply model changes
Make the requested change to the entity class or `DbContext` (add property, rename column, new table, etc.).

### 2. Detect context name
```bash
grep -r "DbContext" {ProjectPath} --include="*.cs" -l
```
Use the found class name for the `-c` flag. If multiple contexts exist, ask the owner which one.

### 3. Suggest migration name
- Format: `PascalCase`, short, descriptive
- Good: `AddOrderStatusColumn`, `RenameUserToCustomer`, `CreateInvoiceTable`
- Bad: `Update1`, `Fix`, `Changes`
- Show the name to the owner before running

### 4. Generate migration
```bash
dotnet ef migrations add {MigrationName} -c {ContextName} -p {ProjectPath} -s {StartupProjectPath}
```
Read the generated `Migrations/{timestamp}_{MigrationName}.cs` and summarize:
- Tables/columns added or dropped
- Any data loss risk (dropping columns = warn explicitly)

### 5. Confirm before update
**STOP. Show the owner the summary. Wait for explicit "ok" or "yes" before continuing.**

### 6. Apply to database
```bash
dotnet ef database update -c {ContextName} -p {ProjectPath} -s {StartupProjectPath}
```
Report success or error. On error, show the SQL that failed.

### 7. Stage migration files
```bash
git add Migrations/
git add {ChangedEntityOrContextFile}
```
Do NOT commit — let the owner decide the commit message.

## Rollback reference (always show after update)

```bash
# Roll back to previous migration
dotnet ef database update {PreviousMigrationName} -c {ContextName}
# Remove last migration (only if not applied to production)
dotnet ef migrations remove -c {ContextName}
```

## Hard rules

- NEVER run `database update` in production without the owner's explicit approval
- NEVER delete existing migration files
- NEVER run `migrations remove` on a migration already applied to a shared/prod DB
- If the migration drops a column with data, warn: "**DATA LOSS RISK** — column `{col}` will be dropped"
