# oh-my-gfw

两条出网链路的配置，见 [README.md](README.md) 的结构表。

- **改 Surge 那条** — 进 [`surge/`](surge/)，读它自己的 `AGENTS.md`。那是一个 Bun +
  argc 的 CLI，构建、发布、schema 约定都在里面。
- **改 mihomo 那条** — 进 [`mihomo/`](mihomo/)，读 `README.md`。那里没有代码，只有
  一份配置模板；改完由 hq 渲染（命令合同查 `hq @schema .secret`），不要手改渲染产物。
- **改分流语义** — 两边都要改，否则会漂移。规则顺序、组成员、出口选择的对照关系在
  [mihomo/README.md](mihomo/README.md) 的能力对照表。
- **发布** — 只有 `surge/` 那个 CLI 有发布流程，用 `.agents/skills/release/SKILL.md`；
  CI 与 release workflow 的 `working-directory` 已指向 `surge/`。
