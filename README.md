# oh-my-gfw

dio 的出网配置。两条链路，同一套分流语义。

| 目录 | 内核 | 状态 | 入口 |
| --- | --- | --- | --- |
| [`surge/`](surge/) | Surge 6（macOS/iOS，闭源商业） | 现役 | [surge/README.md](surge/README.md) |
| [`mihomo/`](mihomo/) | mihomo v1.19.29（Go，开源） | 试用 | [mihomo/README.md](mihomo/README.md) |

## 为什么是两条

Surge 的 `#!include` 不能跨 profile 聚合节点、不能给节点加前缀、不能按关键字自动组池，
所以 `surge/` 里有一个 CLI（`surge-merge`）把机场订阅和 AI 分流规则合成一份 `Merged.conf`。

mihomo 把这三件事都做进了内核（`override.additional-prefix`、`include-all-providers`
+ `filter`、`proxy-providers` 自带订阅刷新），所以 `mihomo/` 里没有构建工具，只有一份
手写配置。

迁移若落地，`surge/` 连同它的 CLI 一起归档——那 800 多行构建逻辑届时没有存在理由。
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
