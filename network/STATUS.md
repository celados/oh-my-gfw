---
type: State
title: 家庭光猫与路由器网络状态
description: 四川电信家用链路的 IPv6 处置结果、最终拓扑、验收数据与回滚边界。
status: resolved
generated: { by: openai-codex/gpt-5, at: "2026-09-02T00:00:00Z" }
stale_after: 2026-10-02
tags: [network, ipv6, tailscale, home-network]
---

# 家庭光猫与路由器网络状态

## 结论

- 已解决：Huawei K662c 已切换为桥接模式，ZTE 光猫是唯一家庭路由器，直接负责 IPv4 DHCP 与 IPv6 RA/地址下发。
- 手机、`oh`、dio Mac 都能获得 `240e:` 全局 IPv6；`oh` 与 Mac 均已改为光猫网段 DHCP。
- Tailscale 已使用 IPv6 endpoint 直连，不再依赖 SFO DERP。
- 家宽内网静态 IP 已无必要；跨网络安全入口使用 Tailscale MagicDNS / tailnet 地址，本地地址只需 DHCP。

## 最终拓扑

```text
Sichuan Telecom
  └─ ZTE ZXHN F7615TV3  192.168.1.1
     │ IPv4 DHCP + IPv6 RA
     └─ Huawei K662c  bridge/AP
        ├─ oh       enp6s0 192.168.1.176  (DHCP)
        └─ dio Mac  en0    192.168.1.20   (DHCP)
```

## 设备状态

### ZTE ZXHN F7615TV3

- 10G-EPON 天翼网关，软件 `24ZTW40001`。
- 管理 IP：`192.168.1.1`。
- 手机直连光猫 Wi-Fi 可拿到两个 `240e:` 地址。
- `oh` 直连光猫有线口也可拿到两个 `240e:` 地址并访问 IPv6 外网。
- 管理页显示的 LAN IPv6 只有 `fe80::1` 不能代表实际 RA 下发能力；最终验收证明光猫可正常向 LAN 下发 IPv6。

### Huawei K662c

- 产品 `K662c`，四川电信定制标识 `SCCTAP`。
- 原路由模式下 WAN 连接被固件固定为 IPv4；虽然表单存在 `IPv4/IPv6` 与 DHCPv6-PD 选项，但该 `TR069_INTERNET` 连接不可编辑。
- 已从“路由”切换为“桥接”，仅承担 Wi-Fi/有线桥接，不再做 NAT、IPv4 DHCP 或 IPv6 前缀分配。
- 桥接切换后 Wi-Fi ready 时间较长，期间 macOS 自动切到手机热点；等待并手动重连 HD 后恢复正常。这是该设备观察到的行为，不代表光猫故障。
- 桥接后管理地址观察到为 `192.168.1.3`。

### oh

- NetworkManager 活动 profile：`Wired DHCP`。
- IPv4：DHCP 获取 `192.168.1.176/24`，网关/DNS 为 `192.168.1.1`。
- IPv6：获取两个 `240e:398:1f0:4550::/64` 全局地址，默认路由来自 `fe80::1` RA。
- IPv4 `ping 223.5.5.5` 成功，约 5–6ms。
- IPv6 `ping 2400:3200::1` 成功，约 32ms。
- 绕过本机 HTTP 代理后，`curl -6 https://api64.ipify.org` 返回 `240e:` 地址。
- 旧 profile `Wired connection 1` 仍保留 `192.168.101.24/24` 静态配置，仅作回滚；当前没有业务需要恢复它。

### dio Mac

- Wi-Fi：HD。
- IPv4：DHCP 获取 `192.168.1.20/24`，网关/DNS 为 `192.168.1.1`。
- IPv6：获取两个 `240e:398:1f0:4550::/64` 全局地址，默认路由来自 `fe80::1`。
- 绑定 `en0` 的 `curl -6 https://api64.ipify.org` 返回 `240e:` 地址。
- Surge 增强模式运行时，`networksetup`/`scutil` 可能短暂报告未关联 Wi-Fi 或无 IPv6 状态；验收以 `ifconfig en0`、IPv6 路由和绑定接口的 curl 为准。

## Tailscale 验收

桥接前：

- `oh` UDP 可用，NAT 映射稳定，但无 IPv6，Mac → `oh` 走 SFO DERP。

桥接后：

- Mac → `oh` 的 Tailscale endpoint 为 `oh` 的全局 IPv6 地址与 UDP 端口。
- `tailscale ping` 直连成功，此前 SFO DERP 回退消失。
- 远程访问使用 Tailscale MagicDNS / tailnet 地址，不依赖家庭内网 IPv4 静态地址。

## 回滚与后续

1. 客户端保持 DHCP；不要再配置 `192.168.101.x` 静态地址。
2. 如需临时回滚 `oh`，先把 Huawei 切回路由模式，再执行 `sudo nmcli connection up "Wired connection 1"`。
3. 如需整体回滚，将 Huawei 从桥接切回路由并等待完全 ready，再恢复需要的静态客户端。
4. 若后续更换 AP/路由器，要求明确支持 bridge/AP 模式与 IPv6 passthrough/PD；本问题与 2000M 带宽、固定公网 IPv4 无关。

## 边界与凭据

- 本文档不保存真实密码。
- 设备凭据只存 Vaultwarden；仓库内只允许保留 `{{ bw://<item-id>/<field> }}` 模板引用。
- 修改 Huawei 网关模式、光猫配置、`oh` 网络配置或重启网络服务前，必须有防断网与回退方案。

| 设备 | Vaultwarden item | 管理入口 |
| --- | --- | --- |
| Huawei K662c | `5437c196-54a9-4adf-96c5-32fc8f41acef` | `http://192.168.1.3/` |
| ZTE ZXHN F7615TV3 | `0b0e354f-c720-4e03-ad92-7f1f50620a7a` | `http://192.168.1.1/` |

模板：[`devices.env.tpl`](devices.env.tpl)。渲染产物是 `devices.env`，已加入 `.gitignore`；不要把渲染结果提交或粘贴到日志。

给客服、装维或后端支撑沟通时，优先使用 [`STATUS.telecom.md`](STATUS.telecom.md) 的简报。
