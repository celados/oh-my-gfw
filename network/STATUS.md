---
type: State
title: 家庭光猫与路由器网络状态
description: 四川电信家用链路、IPv6 诊断结果、Tailscale 现状与后续处置路线。
status: active
generated: { by: openai-codex/gpt-5, at: "2026-09-02T00:00:00Z" }
stale_after: 2026-10-02
tags: [network, ipv6, tailscale, home-network]
---

# 家庭光猫与路由器网络状态

## 结论

- 四川电信已经在光猫 WAN 侧提供全局 IPv6；问题不在“未开通 IPv6 业务”。
- 光猫 LAN 侧没有把可路由 IPv6 前缀传给下挂网络，当前不能通过下游路由器凭空生成公网 IPv6。
- 需要电信后端重新下发/修复光猫数据；若后端无法修复，应改桥接并由 Huawei 做 PPPoE，或更换按正确模板开通的光猫。
- 在光猫 LAN 侧拿到前缀之前，不要为“生成 IPv6”改动 Huawei 或 `oh`。

## 链路拓扑

```text
Sichuan Telecom
  └─ ZTE ZXHN F7615TV3  192.168.1.1  (route)
       └─ Huawei K662c   WAN 192.168.1.3 / LAN 192.168.101.1  (route)
            ├─ oh       enp6s0 192.168.101.24  (static)
            └─ dio Mac  en0    192.168.101.65
```

## 2026-09-02 快照

### ZTE ZXHN F7615TV3

- 设备类型：10G-EPON 天翼网关（双频 WiFi6）。
- 软件：`24ZTW40001`。
- LAN IPv4：`192.168.1.1/24`。
- WAN IPv4：`100.64.1.191`。
- WAN IPv6：存在 `240e:` 全局地址。
- LAN IPv6：仅 `fe80::1` 链路本地地址；普通 `useradmin` UI 没有 LAN IPv6/RA/DHCPv6/PD 配置入口。
- 电话与 IPTV 显示已开通，因此改桥接或恢复出厂前必须先确认迁移与回退方案。

### Huawei K662c

- 产品：`K662c`，四川电信定制界面标识 `SCCTAP`。
- WAN：从光猫自动获取 `192.168.1.3`。
- LAN IPv4：`192.168.101.1/24`。
- 网关模式：路由模式。
- WAN 连接：`1_TR069_INTERNET_R_VID_-/-IPv4`，仅 IPv4。
- DHCPv6 服务：已开启；接口地址只有 `fe80::101`。
- 获取前缀方式：`WAN代理`，但父前缀来源为空。
- LAN 资源分配：RA 与 DHCPv6 Server 已开启；地址使用无状态 SLAAC，其他信息使用 DHCPv6。
- 上述配置解释了为什么 LAN 设备最多只有链路本地 IPv6。

### oh

- 物理口：`enp6s0`，Realtek RTL8125。
- IPv4：静态 `192.168.101.24/24`。
- IPv4 网关/DNS：`192.168.101.1`。
- IPv6：`enp6s0` 只有链路本地地址；没有全局 IPv6 和 IPv6 默认路由。
- Tailscale：`100.83.72.30` 与 tailnet IPv6。

### dio Mac

- 出网默认路由由 Surge 增强模式接管；Tailscale 保留独立边界。
- 有线/Wi-Fi 侧位于 Huawei LAN，IPv4 为 `192.168.101.65`。
- 物理上游接口的 IPv6 设置为 Automatic，但没有 IPv6 地址、网关或默认路由。

## Tailscale 诊断

`oh` 的 `tailscale netcheck` 结果：

- UDP：可用。
- IPv4：`110.184.243.122:26816`。
- `MappingVariesByDestIP`：`false`，NAT 映射稳定。
- IPv6：不可用，但 OS 支持。
- 没有观察到可用端口映射。
- DERP 延迟里最近为 San Francisco；Hong Kong 延迟约 270ms。
- 控制面请求会经过本机 `127.0.0.1:7890` 代理；这只是 HTTP 控制面观察项，不代表 WireGuard UDP 走该代理。

IPv4 直连失败尚不能归因于缺少 IPv6。后续应继续检查 peer endpoint、防火墙、ACL 和双方打洞结果。

## 故障处置路线

1. 优先要求电信后端重新下发光猫双栈数据，验收标准是直连光猫的设备拿到 `240e:` 全局地址。
2. 若后端无法修复，要求光猫改桥接并由 Huawei 做 PPPoE；此路径需要先取得 PPPoE/VLAN 数据，并保护电话与 IPTV。
3. 若仍不能解决，要求更换按正确模板开通的光猫。
4. 光猫侧修好后，再将 Huawei 改为 AP/桥接，并把 `oh` 从静态 IPv4 改为 DHCP，避免切换时失联。

## 边界

- 本文档不保存任何真实密码。
- 设备凭据只存 Vaultwarden；仓库内只允许保留 `{{ bw://<item-id>/<field> }}` 模板引用。
- 修改 Huawei 网关模式、光猫桥接、`oh` 网络配置或重启网络服务前，必须有防断网与回退方案。

## 凭据路径

| 设备 | Vaultwarden item | 管理入口 |
| --- | --- | --- |
| Huawei K662c | `5437c196-54a9-4adf-96c5-32fc8f41acef` | `http://192.168.101.1/` |
| ZTE ZXHN F7615TV3 | `0b0e354f-c720-4e03-ad92-7f1f50620a7a` | `http://192.168.1.1/` |

模板：[`devices.env.tpl`](devices.env.tpl)。渲染产物是 `devices.env`，已加入 `.gitignore`；不要把渲染结果提交或粘贴到日志。
