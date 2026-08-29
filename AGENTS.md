# oh-my-gfw

两条出网链路的历史与状态，见 [README.md](README.md) 的结构表。

- **Surge 是现役运行时** — 运行时操作先读 `.agents/skills/surge/SKILL.md` 并使用
  `surge-cli`。真实配置源是 Surge Profiles 下的本地未跟踪文件，仓库内示例不是
  live state；不要只看静态文件判断实际路由。
- **网络排障硬门禁** — 默认只读；任何可能重建 TUN、改变路由/DNS 或中断连接的 reload、restart、switch 操作，必须先给出防断网与恢复方案并获得用户明确确认，禁止在承载当前 agent session 的网络上直接试验。
- **mihomo 是已归档的失败试行** — 只读 [`mihomo/README.md`](mihomo/README.md)
  了解结论与回滚资产。Mac 本机的 `com.celados.mihomo` LaunchDaemon 已停用并禁用；
  没有明确回滚指令时不得重新启用。
- **改分流语义** — 以 Surge 现役配置为准。mihomo 配置只保留为实验/回滚资产，
  不与 Surge 自动同步。
- **发布** — 只有 `surge/package.json` 的版本变化能进入 Release 路径；状态/文档更新不触发发布。
