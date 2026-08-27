# oh-my-gfw

dio 的出网配置。两条链路，同一套分流语义。

| 目录 | 内核 | 状态 | 入口 |
| --- | --- | --- | --- |
| [`surge/`](surge/) | Surge 6（macOS/iOS，闭源商业） | 已退役(2026-08-27 退场,保留为回滚资产) | [surge/README.md](surge/README.md) |
| [`mihomo/`](mihomo/) | mihomo v1.19.30（Go，开源） | 现役(TUN 模式) | [mihomo/README.md](mihomo/README.md) |

## Agent 入口：当前网络拓扑

先读 [`mihomo/README.md` 的“网络拓扑速览”](mihomo/README.md#网络拓扑速览2026-08-27)。
那里集中记录节点身份、tailnet/MagicDNS、SSH 入口、路由与 DNS 边界、已验证链路和
尚未打通的 share 边界。简写：`hd-1` 是 dio Mac，`hz` 是 Hetzner `ops-1`，
`do` 是家里的 `oh`；前两者在 `huodong.work@gmail.com` tailnet，`do` 当前在
Denniffer 的 tailnet，等待 node share。


## 为什么是两条

Surge 的 `#!include` 不能跨 profile 聚合节点、不能给节点加前缀、不能按关键字自动组池，
所以 `surge/` 里有一个 CLI（`surge-merge`）把机场订阅和 AI 分流规则合成一份 `Merged.conf`。

mihomo 把这三件事都做进了内核（`override.additional-prefix`、`include-all-providers`
+ `filter`、`proxy-providers` 自带订阅刷新），所以 `mihomo/` 里没有构建工具，只有一份
手写配置。

迁移已落地(2026-08-27 切换完成,验证记录见 [mihomo/README.md](mihomo/README.md)
迁移状态段)。`surge/` 保留为回滚资产,soak 一个稳定周期后连同 CLI 一起归档。
完整能力对照表在 [mihomo/README.md](mihomo/README.md)。

## 共同的分流语义

两边表达的是同一件事：

- **多机场订阅合并**，节点带来源前缀
- **按地区跨源聚合**成 url-test 池（当前只有日本池 `AI-Relay-JP`）
- **链式出口**：Webshare 家宽 IP 落地，出境经机场日本节点中转
- **按进程分流**：Claude / Codex / Grok / GoogleAI 各自独立的出口选择
- **国内 AI 网关强制直连**：`claude-*` 变种共用同一个进程，必须靠域名先行截胡

## 密钥

两边的凭据都不进 git：`surge/config/default.ts` 直接 gitignore；`mihomo/config.yaml`
由 `config.yaml.tpl` 渲染。走 Vaultwarden + `hq secret.render`，与 `berth` 一致。
