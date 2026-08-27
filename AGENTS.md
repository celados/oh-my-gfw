# oh-my-gfw

两条出网链路的配置，见 [README.md](README.md) 的结构表。

- **Surge 那条** — 已退役(2026-08-27 退场),只读回滚资产:Surge app、Profiles、
  CLI 都不再改;回滚 = 重开 Surge app(系统代理不用动,它走自己的 TUN)。
- **改 mihomo 那条** — 进 [`mihomo/`](mihomo/)，读 `README.md`。那里没有代码，只有
  一份配置模板；改完由 hq 渲染（命令合同查 `hq @schema .secret`），不要手改渲染产物。
- **改分流语义** — mihomo 是唯一现役源,只改它。`surge/Merged.conf` 不再同步,
  [mihomo/README.md](mihomo/README.md) 的能力对照表仅作历史参考。
- **发布** — `surge/` 的 CLI 已随退役冻结,`.agents/skills/release` 与 release
  workflow 不再使用。
