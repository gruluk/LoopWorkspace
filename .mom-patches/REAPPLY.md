# Mom-mode patches

Saved 2026-10-04 before creating the `gruluk` forks and the `mom` branch.

Apply on a clean official checkout of the same base commits:

- Loop: `c2fddb76` (Loop 3.14.8 workspace pin)
- LoopKit: `325bd820`
- LoopWorkspace: `f841285` plus `LoopConfigOverride.xcconfig`

```sh
# Loop
git -C Loop apply --3way .mom-patches/Loop/all.diff

# LoopKit
git -C LoopKit apply --3way .mom-patches/LoopKit/all.diff

# Workspace flag
git apply --3way .mom-patches/LoopWorkspace/LoopConfigOverride.xcconfig.patch
```

If a patch fails, copy files from `.mom-patches/snapshots/`.
