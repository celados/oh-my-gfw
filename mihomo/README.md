---
type: Playbook
title: mihomo on Mac
description: >
  dio Mac 上的 mihomo 配置：从 Surge 迁移而来的等价分流，含渲染、订阅刷新、
  与 tailscale 共存的取舍，以及迁移期哪些已验证、哪些还没有。
when: >
  在 Mac 上安装、渲染、启动或排查 mihomo；调整 AI 分流出口；刷新机场订阅；
  或判断某项 Surge 能力在 mihomo 这边对应什么。
status: trial
generated: { by: claude-code/opus-5, at: 2026-08-05T00:00:00Z }
---

# mihomo on Mac

Surge 的替代方案，试用期。语义与 [`../surge/`](../surge/) 那条链路一一对应，
但**没有构建步骤**——节点前缀、跨源聚合、订阅刷新都是内核原生能力，配置就是最终态。

对照关系见 [`../README.md`](../README.md)。

## 装 / 渲染 / 跑

```sh
# 1. 内核(当前 v1.19.30;v1.19.29 起原生支持 anytls,不需要转换订阅)
cp <mihomo 二进制> ~/.local/bin/mihomo

# 2. 渲染配置(填入 Vaultwarden 里的 Webshare 凭据)
hq secret.render "{ file: 'mihomo/config.yaml.tpl' }"

# 3. 安装并启动
mkdir -p ~/.config/mihomo
cp mihomo/config.yaml ~/.config/mihomo/config.yaml
mihomo -d ~/.config/mihomo
```

`7890` 是混合代理端口，`9090` 是 external-controller。停止用 `pkill -f "mihomo -d"`。

**geodata 要手动放**：`GeoIP.dat` / `GeoSite.dat` 复制到 `~/.config/mihomo/`
（可从 `berth/systemd/mihomo/` 拿）。配置里关掉了自动下载——mihomo 会阻塞在
geodata 下载上直到成功才开始监听，失败还会留下截断的 `.dat`，这条教训来自 oh 的部署。

## 凭据

`config.yaml.tpl` 里 Webshare 家宽代理(`s22`)的 server/username/password 走
`{{ bw:// }}` 占位，渲染产物 `config.yaml` 已 gitignore。

条目已建：Vaultwarden Shared 集合 `webshare-s22`
（`3e033f2a-2fbc-49cc-aa01-c793a62cb42d`，2026-08-25），渲染管线已闭环。

## 订阅

`proxy-providers.airport` 当前是 `type: file` 快照，内容从 oh 的
`/etc/mihomo/providers/airport.yaml` 拷贝而来。

**这家机场的订阅 URL 带一次性闸门**：URL 本身稳定（Vaultwarden
`9ca7d6c0-8234-4d61-bd40-6cc340ea9326`），但每次拉取前必须去机场用户后台的订阅
详情页手动开启，之后只有 10 分钟窗口；窗口外返回中文提示文本而不是 YAML。
所以定时刷新不成立，切回 `type: http` 的写法和刷新命令写在配置文件注释里。

从 oh 拷贝快照时注意：`ssh` 会把 OSC 终端控制序列混进 stdout，导致 YAML 解析报
`control characters are not allowed`。清理方式：

```sh
perl -0pe 's/\033\][^\a]*\a//g; s/\r\n/\n/g' airport.yaml > airport.clean.yaml
```

## 为什么不开 TUN

不开 TUN 是这套配置的核心前提，不是省事：

- **tailscale 不受影响**。TUN 会接管默认路由并劫持 DNS，跟 MagicDNS
  (100.100.100.100) 打架。当前配置只监听端口、不碰路由表 / DNS，`tailscaled` 完全无感。
- **进程分流照样能用**。实测 macOS 上仅靠 `mixed-port` + `find-process-mode: strict`
  （非 root、无 TUN）就能拿到进程路径，`PROCESS-PATH-WILDCARD` 正常命中。这是
  整个迁移可行的前提。

代价：不认 `HTTP_PROXY` / 系统代理设置的程序抓不到。Surge 的增强模式
（签名 System Extension）没有这个限制——这是两边最实在的架构差异。

真要开 TUN 时，用 `route-exclude-address` / `exclude-interface` 把 tailnet 摘出去。

## tailscale 实装（2026-08-25）

brew formula（CLI 版 v1.102.3）：`sudo brew services start tailscale` 常驻，
LaunchDaemon 带 keepalive + runatload。`tailscale up --accept-dns=false`——
Surge 增强模式仍在接管 DNS，先不引入 MagicDNS，切换后重新评估。

设备 `hd` = 100.127.191.38，tailnet `huodong.work@`（新建，暂无其他设备）。
netcheck `UDP: false`：推断是 Surge System Extension 拦了 STUN，走 DERP 中继兜底，
预期 Surge 退场后恢复直连——切换时这是 netcheck 复测项。

## Surge 能力对照

| Surge | mihomo | 备注 |
| --- | --- | --- |
| `underlying-proxy=<组名>` | `dialer-proxy: <组名>` | 精确等价，两边都能指向策略组 |
| `PROCESS-NAME,<带*的路径>` | `PROCESS-PATH-WILDCARD` | 仅支持 `*` 和 `?` |
| `PROCESS-NAME,<完整路径>` | `PROCESS-PATH` | |
| `sources[].prefix` | `override.additional-prefix` | 内核原生，无需构建 |
| `relays`（跨源聚合） | `include-all-providers` + `filter` | |
| `aggregate.sources`（限定源） | `use: [<provider>]` + `filter` | |
| `RULE-SET,<url>` | `rule-providers` (`classical` / `text`) | 同一批 URL 直接可用 |
| `skip-proxy` / `RULE-SET,LAN` | `GEOSITE,private` + `GEOIP,private` | |
| `udp-policy-not-supported-behaviour` | **无等价** | 见下 |
| MITM / URL Rewrite / Header Rewrite | **无** | 当前配置未使用 |

`USER-AGENT` 规则（HotKids 那三个规则集里有）mihomo 不支持，实测是 warning 跳过
单行，provider 其余规则照常加载，不影响启动。

**没有 `udp-policy-not-supported-behaviour` 兜底**：Surge 那边靠它把不支持 UDP 的
出口回退成 DIRECT，避免静默丢包（lore push 的 QUIC UDP 41337 曾因此排障半天）。
这里唯一的防线是 rules 段 `DOMAIN-SUFFIX,celados.com,DIRECT`，别删。

## 迁移状态

已验证：130 节点加载、池聚合（JP 19 / 通用 63）、AI 组成员与默认选中同 Surge 一致、
22 个规则集全加载（136,773 条）、分流命中全部符合预期、`s22` 出口 IP 与 Surge 一致。

**未验证**：走机场 anytls 节点的出站。Surge 增强模式会捕获 mihomo 的出站连接形成
嵌套，握手报 `failed to create session: EOF`。同版本内核 + 同订阅在 oh 上正常出网
（已实测），所以这是同机共存问题，不是配置缺陷——需要 Surge 退场后补验证。

## 还缺什么

- **GUI**：Mac 上需要一个客户端接管系统代理开关（Mihomo Party / Clash Verge Rev）。
  当前是裸 CLI，系统代理要自己设。
- **iOS**：mihomo 没有官方 iOS 客户端。若 iPhone 上还在用 Surge，这条不是配置能解决的。
