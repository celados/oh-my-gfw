---
type: Brief
title: IPv6 处置简报：光猫正常，路由器已改桥接
description: 给客服、装维和后端支撑说明复测结论、已完成的处理与最终验收结果。
resource: ./STATUS.md
status: resolved
generated: { by: openai-codex/gpt-5, at: "2026-09-02T00:00:00Z" }
stale_after: 2026-10-02
tags: [network, ipv6, telecom, escalation]
---

# IPv6 处置简报：光猫正常，路由器已改桥接

## 一句话结论

问题已解决。电信光猫本身能正常下发 IPv4/IPv6；问题在 Huawei K662c 原路由模式没有转发 IPv6。Huawei 已改为桥接/AP，由光猫直接给所有设备分配地址。

## 证据与验收

| 位置 | 结果 | 说明 |
| --- | --- | --- |
| 手机直连光猫 Wi-Fi | 两个 `240e:` 地址 | 光猫 Wi-Fi LAN 可下发全局 IPv6。 |
| `oh` 直连光猫有线口 | 两个 `240e:` 地址、IPv6 默认路由、外网可通 | 光猫有线 LAN 可下发全局 IPv6。 |
| Huawei K662c | 已改为桥接 | 消除二级路由和 IPv6 断点。 |
| `oh` 最终状态 | DHCP `192.168.1.176` + 两个 `240e:`，IPv4/IPv6 外网可通 | 有线客户端验收通过。 |
| dio Mac 最终状态 | DHCP `192.168.1.20` + 两个 `240e:`，IPv6 HTTPS 返回 `240e:` | Wi-Fi 客户端验收通过。 |
| Tailscale | Mac → `oh` 使用 `oh` 的 IPv6 endpoint 直连 | SFO DERP 回退消失。 |

## 结论边界

不需要升级 2000M，不需要办理固定公网 IPv4，不需要更换光猫。该问题与带宽和固定 IPv4 无关。

Huawei 切桥接后 ready 时间较长，Wi-Fi 可能短暂消失，macOS 可能自动切到手机热点；等待后手动重连 HD 即可。所有客户端应使用 DHCP，不需要家庭内网静态 IPv4；远程入口使用 Tailscale MagicDNS / tailnet 地址。

## 可直接复制的话

> 复测和处理已经完成：手机和 `oh` 直连光猫都能拿到 `240e:`，说明光猫正常；把华为 K662c 切成桥接后，Mac 和 `oh` 也都能拿到 `192.168.1.x` 与 `240e:`，IPv4/IPv6 外网和 Tailscale 直连均通过。  
> 本问题与 2000M 带宽、固定公网 IPv4 无关，不需要继续升级套餐或更换光猫。
