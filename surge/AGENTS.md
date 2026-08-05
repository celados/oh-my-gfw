# surge-merge

An agent-native CLI built with [argc](https://github.com/ethan-huo/argc) on Bun.

- **Building this tool** — use the `argc` skill. It owns the schema design,
  handler, stdout, and release conventions; don't restate them here.
- **Using this tool** — `skills/surge-merge/SKILL.md` is the agent-facing usage
  guide. Keep it in sync as commands change.
- **Releasing this tool** — use `../.agents/skills/release/SKILL.md`; release is a
  `package.json` version bump pushed to `main`, then the workflow tags and
  publishes. CI/release run with `working-directory: surge`.
- **This is one of two links** — the mihomo side lives in `../mihomo/`. Changing
  routing semantics here without mirroring it there makes the two drift; see
  `../README.md`.
- **Runtime is Bun** — prefer its native APIs and check the source of truth at
  <https://bun.sh/llms.txt> instead of guessing from memory.
