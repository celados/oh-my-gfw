---
type: State
title: Surge runtime state
description: dio Mac 当前出网运行时、AI 长连接诊断、Tailscale 边界与 Mihomo 回滚资产。
status: active
generated: { by: openai-codex/gpt-6, at: "2026-09-15T10:27:00Z" }
stale_after: 2026-09-22
---

# Surge runtime state

## Current

- Surge Mac **6.7.0** is the active default-network runtime.
- Enhanced Mode / `com.nssurge.surge-mac.ne` is installed and enabled; default IPv4
  traffic goes through Surge's `utun5` (verified 2026-09-15; interface numbers can change).
- Public system DNS uses Surge's `198.18.0.2`. Tailscale `accept-dns=false`;
  Surge forwards only `*.tailaf8030.ts.net` and configured device short names to
  MagicDNS at `100.100.100.100`, reached over Tailscale's `utun4`.
- Current short names are explicitly mapped in the local profile (including `oh`
  and `ops1`), with no fixed device IPs. Newly added devices work by full tailnet
  name; add a short-name mapping if needed. Tailnet names use `always-real-ip`
  to preserve native Tailscale routing.
- Tailscale Standalone remains installed and online. It owns the tailnet
  `100.64.0.0/10` boundary and does not replace Surge as the default route.
- Mihomo is retired from runtime use. Its process is stopped,
  `system/com.celados.mihomo` is disabled, and the binary/config/plist remain only as
  rollback assets.

## DNS 分流修复（2026-09-15）

现象：Aside 的 B 站主站命中 ChinaIPs 直连，但 `s1.hdslb.com` 和
`i0.hdslb.com` 以真实 IP 连接，落到 FINAL 香港代理。规则集已加载且包含
`hdslb.com`；系统 DNS 与 Tailscale DNS 同样返回 `163.181.87.*` /
`156.227.14.33` 等地址，Tailscale 报告其系统上游为 `1.1.1.1`。

经用户授权，在本机 Profiles 的 `surge-merge.config.ts` 和 `Merged.conf` 中：

- 将尾网域名与当前设备短名称的 DNS 指向 `100.100.100.100`，配置
  `always-real-ip`；关闭 Tailscale 系统 DNS 接管，保留 Tailscale 本身在线。
- 给 Bilibili RULE-SET 添加 `extended-matching`，覆盖浏览器缓存真实 IP
  时的 TLS SNI 匹配。参见 [Surge 域名规则](https://manual.nssurge.com/rules/domain.html)。
- MagicDNS 在关闭 accept-dns 后仍可直接查询，参见
  [Tailscale DNS 说明](https://tailscale.com/docs/reference/faq/dns-resolv-conf)。

验证：候选配置与从源重新生成的配置均通过 Surge 校验；系统公网解析返回
Surge 虚拟 IP，`oh` / 完整尾网域名解析到 `100.83.72.30`，
`ssh -o BatchMode=yes oh true` 成功。外网 HTTPS 返回 204。Aside 新开 B 站页面
返回 200，load 约 1.1 秒；其主站、接口、`s1.hdslb.com`、`i2.hdslb.com`
均命中 Bilibili DIRECT。单次加载不能证明所有偶发卡顿已消失。

备份位于本机 `~/Library/Application Support/Surge/Profiles/dns-backup-20260915-182507/`。
独立 5 分钟自动回滚在验证通过后以 COMMITTED 标记解除。需要恢复时，在获得
网络维护授权后恢复该目录的原 `Merged.conf` 和 `surge-merge.config.ts`，
执行 `tailscale set --accept-dns=true`，再 reload Surge；该操作可能中断连接。
凭据与备份不进入 Git。

## Claude long-connection investigation (2026-09-09)

- Symptom: Claude Code frequently showed `API error · Retrying` during streaming
  responses. Its local session records contained four `Connection dropped
(ECONNRESET)` failures between 15:46 and 17:35 +08; no matching HTTP 429 or
  Anthropic 5xx response was found.
- The active route at diagnosis time was `Claude -> s22-via-JP`: a Japanese
  `AI-Relay-JP` node carried the connection to the s22 US residential proxy, which
  then connected to Anthropic. Surge records captured `Read stream EOF` and `TCP
error: Connection reset` on this path. The automatic relay selection moved from
  `CD-🇯🇵 JP | 日本 13` to `Amy-🇯🇵 日本 06` during the observation window.
- The local access network did not show a concurrent general outage: 100 probes to
  `192.168.1.1` and 50 probes to `223.5.5.5` had zero packet loss; Wi-Fi remained
  associated with normal signal quality. Repeated short HTTPS probes also completed.
- Working diagnosis: the Japanese relay layer, its automatic node changes, or the
  additional chained hop is the leading cause. A `url-test` result measures a short
  HTTP request and does not establish long-lived streaming reliability; the evidence
  does not yet prove that a node-change instant caused each reset.
- Current experiment: Ethan manually changed the Claude policy from `s22-via-JP` to
  direct `s22`, removing the Japanese relay hop. This is an observation in progress,
  not a confirmed fix. Compare the frequency of Claude `ECONNRESET` failures during
  normal long sessions. If they largely disappear, attribute the failure to the relay
  layer; if they continue, investigate s22 itself and its path to Anthropic.
- Keep this comparison read-only. Do not reload Surge or alter TUN, routes, or DNS to
  test it; those actions can interrupt the active agent session and remain behind the
  network safety gate.

## Verification (2026-08-27 19:19 +08)

- Surge extension state: `activated enabled`.
- Default, `1.1.1.1`, and `8.8.8.8` routes resolved through Surge `utun7`.
- Tailscale `100.100.100.100` resolved through its own `utun6`.
- Repeated probes passed: Baidu `200`, Google `204`, ChatGPT `200`, and
  `wetype.weixin.qq.com` reachable.
- Tailscale remained online; netcheck fell back to DERP (Hong Kong about 47 ms)
  because direct UDP was unavailable. Treat this as the current Surge 6.7 +
  standalone Tailscale trade-off.

## Failure context

Mihomo's initial cutover passed static routing and proxy tests, but later Wi-Fi/network
transitions triggered `default interface lost by monitor` followed by `interface not
found` and DIRECT/Proxy timeouts. WeChat and WeType later recovered without a config
change. The failing connections did not traverse Tailscale, so the primary failure was
Mihomo TUN interface recovery rather than node quality or Tailscale.

## Rollback asset

Do not re-enable Mihomo as an experiment while Surge owns the default route. A deliberate
rollback must stop Surge first, restore Wi-Fi DNS to `1.1.1.1`, then enable/bootstrap
`/Library/LaunchDaemons/com.celados.mihomo.plist`. Keep the operation in a dedicated
maintenance window.
