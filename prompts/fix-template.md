# Build-Fix Cycle

The app you built has **{ERROR_COUNT}** compile errors and **{WARNING_COUNT}** warnings.

## Build Errors

```
{BUILD_ERRORS}
```

## Instructions

1. Read each error carefully.
2. Fix the root cause, not the symptom. If an API doesn't exist, use the correct API — don't comment out code or add `as! Any`.
3. Do NOT rewrite entire files. Make targeted fixes.
4. After fixing, output: `ATLAS_FIX_COMPLETE`

## Constraints
- Do NOT remove features or functionality to fix errors.
- Do NOT add `// FIXME` or `// TODO` comments.
- Do NOT use `@unchecked Sendable` unless you add a comment explaining why it's safe.
- Do NOT comment out failing code.
