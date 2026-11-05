Initial GitHub release of DotCast 0.1.3-beta for WoW Forever / Interface 16001.

- Clickable learned class DoTs on enemy nameplates, with per-character spell selection and custom spell/aura IDs.
- Tracks your own effects, active fading, expiration flashing, range and usability states.
- Appearance controls and minimap launcher; works alongside CounterCast.
- Includes bounded callback diagnostics and the saved-macro reuse fix. Existing macros are never deleted.

This is the current installed runtime, published without gameplay changes. 96/96 Lua 5.1 checks pass. Earlier simulator evidence is included in the repository; it does not certify live casting or restricted combat aura access.

Use the attached `DotCast-0.1.3-beta-forever.zip`, not the automatic source archive. WowUp: select Forever and Install from URL using https://github.com/paden1991/DotCast, with the Beta channel selected. New addon folders may require a full game restart.
