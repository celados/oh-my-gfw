---
type: State
title: Surge runtime state
description: dio Mac 当前出网运行时、验证证据、Tailscale 边界与 Mihomo 回滚资产。
status: active
generated: { by: openai-codex/gpt-5, at: "2026-08-27T11:22:40Z" }
---

# Surge runtime state

## Current

- Surge Mac **6.7.0** is the active default-network runtime.
- Enhanced Mode / `com.nssurge.surge-mac.ne` is installed and enabled; default IPv4
  traffic goes through Surge's `utun7`.
- Effective DNS is Surge's `198.18.0.2`; Tailscale MagicDNS remains a supplemental
  resolver for `*.ts.net`.
- Tailscale Standalone remains installed and online. It owns the tailnet
  `100.64.0.0/10` boundary and does not replace Surge as the default route.
- Mihomo is retired from runtime use. Its process is stopped,
  `system/com.celados.mihomo` is disabled, and the binary/config/plist remain only as
  rollback assets.

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
