# DotCast 0.1.3-beta publication validation

Target: WoW Forever, interface 16001. The source and installed addon copies match byte-for-byte across all nine runtime files (eight Lua modules plus TOC). Current recorded implementation API reference: build 1.60.1.70790, bundled source commit eac30af597e5aaa43a60f6675ef5fdcea100375f. No runtime or API changes are introduced by publication.

The complete Lua 5.1 synthetic test harness covers learned spells, per-character selection, player-owned aura states, unreadable data, resources, fade/flash behavior, combat restrictions, recycled plates, bounded callback recovery, macro preservation and full-slot reuse across repeated rebuilds. `verification.json` records the latest run.

Earlier UIForever checks exercised spell selection, appearance, synthetic Rake aura transitions and recovery behavior. `spells-preview.jpg` is an earlier simulator reference. Secure casting remained inconclusive in the simulator. The user confirmed icons returned after the macro-reuse repair; that is icon-recovery evidence, not a new live casting test.

Release validation checks source hashes, interface/version, every TOC module, archive CRC and file equality. The published download is checked against the release checksum and source manifest after upload. No new live-client check was performed for this publication-only task.
