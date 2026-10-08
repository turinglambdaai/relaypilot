# AI diagnostics

AI is an optional diagnosis layer, not the source of truth.

```text
DecisionTrace + bounded engine events
                ↓
         DiagnosticBundle
                ↓ redact locally
          user-selected model
                ↓
           ConfigPatch
                ↓ validate + simulate
             preview diff
                ↓ explicit apply
             Relay Profile
```

`ConfigPatch` operations carry an expected old value. This prevents a stale model response from overwriting a profile that changed after diagnosis. Provider keys and engine credentials are never included in a bundle by default.

