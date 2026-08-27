# oh-my-gfw

dio 的出网配置。两条链路共享同一套分流语义；当前由 Surge 承载。

| 目录 | 内核 | 状态 | 入口 |
| --- | --- | --- | --- |
| [`surge/`](surge/) | Surge 6.7.0（macOS/iOS，闭源商业） | **现役**（Enhanced Mode / System Extension） | [surge/STATUS.md](surge/STATUS.md) |
| [`mihomo/`](mihomo/) | mihomo v1.19.30（Go，开源） | **失败试行，已归档**（LaunchDaemon 已禁用） | [mihomo/README.md](mihomo/README.md) |

## Agent 入口：当前网络拓扑

先读 [`surge/STATUS.md`](surge/STATUS.md)。它记录当前运行时、验证证据、Tailscale
边界与 Mihomo 回滚资产。节点身份、tailnet/MagicDNS、SSH 入口与 DNS 边界的历史快照
保留在 mihomo playbook，但那里不再是现网入口。
简写：`hd-1` 是 dio Mac，留在 `huodong.work@gmail.com` tailnet；Hetzner `ops-1`
的 Tailscale 节点 `ops1` 与家庭主机 `oh` 位于 Denniffer 的 tailnet。

当前事实：Mac 默认流量由 Surge System Extension 接管；Tailscale Standalone 保留并
只处理 tailnet/MagicDNS；Mihomo 二进制、配置与 LaunchDaemon plist 均保留，但服务已
停用且禁用自启。


## 为什么曾有两条

Surge 的 `#!include` 不能跨 profile 聚合节点、不能给节点加前缀、不能按关键字自动组池，
所以 `surge/` 里有一个 CLI（`surge-merge`）把机场订阅和 AI 分流规则合成一份 `Merged.conf`。

mihomo 把这三件事都做进了内核（`override.additional-prefix`、`include-all-providers`
+ `filter`、`proxy-providers` 自带订阅刷新），所以 `mihomo/` 里没有构建工具，只有一份
手写配置。

2026-08-27 的 Mihomo 试行证明分流语义和 anytls 出站可用，但其 TUN
`auto-detect-interface` 在两次 Wi‑Fi/网络切换后进入半可用状态，微信/WeType 的
DIRECT 连接超时后才恢复。结论是它不适合作为这台 Mac 的全天候默认网络；已回退
Surge。完整复盘与能力对照在 [mihomo/README.md](mihomo/README.md)。

## 共同的分流语义

这套语义现在由 Surge 表达：

- **多机场订阅合并**，节点带来源前缀
- **按地区跨源聚合**成 url-test 池（当前只有日本池 `AI-Relay-JP`）
- **链式出口**：Webshare 家宽 IP 落地，出境经机场日本节点中转
- **按进程分流**：Claude / Codex / Grok / GoogleAI 各自独立的出口选择
- **国内 AI 网关强制直连**：`claude-*` 变种共用同一个进程，必须靠域名先行截胡

## 密钥

两边的凭据都不进 git：`surge/config/default.ts` 直接 gitignore；`mihomo/config.yaml`
由 `config.yaml.tpl` 渲染。走 Vaultwarden + `hq secret.render`，与 `berth` 一致。
