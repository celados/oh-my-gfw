---
type: Playbook
title: mihomo on Mac
description: >
  dio Mac 上的 mihomo 配置、当前 tailnet 拓扑(hd-1/hz/oh)、TUN 与 DNS 共存边界、
  从 Surge 迁移的等价分流、渲染、订阅刷新，以及已经验证和仍待完成的链路。
when: >
  需要快速理解 dio Mac、hz/ops-1 与 oh/do 的网络环境;安装、渲染、启动或排查
  mihomo;调整 AI 分流出口;刷新机场订阅;排查 TUN/路由/DNS;或判断 Surge 能力映射时。
status: trial
generated: { by: openai-codex/gpt-5.6-sol, at: '2026-08-27T05:31:47Z' }
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

# 3. 安装
mkdir -p ~/.config/mihomo
cp mihomo/config.yaml ~/.config/mihomo/config.yaml
```

TUN 需要 root(macOS 创建 utun),常驻走 LaunchDaemon
`/Library/LaunchDaemons/com.celados.mihomo.plist`(KeepAlive + RunAtLoad,
日志 `~/.config/mihomo/daemon.{out,err}.log`):

```sh
sudo launchctl kickstart -k system/com.celados.mihomo   # 改配置后重载
sudo launchctl bootout system/com.celados.mihomo        # 停止/回滚
```

# 重载后有 ~20s 窗口系统解析器可能命中否定缓存(curl 报 Could not resolve,
# dig 直查却正常即此因)——等它过期,急就 sudo dscacheutil -flushcache。

系统 DNS 必须指向非 LAN 地址(Wi-Fi 当前 = `1.1.1.1`):macOS 上 dns-hijack
劫持不了发往局域网的 DNS,指路由器就绕过 TUN 了。指向谁无所谓,53 端口一律
在 TUN 层被拦,由 mihomo 的国内外 DoH 分流应答。回滚同步改回:
`sudo networksetup -setdnsservers Wi-Fi Empty`。

`7890` 混合代理端口在 TUN 之外仍可用(显式 `curl -x` 场景),`9090` 是
external-controller。

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

## 网络拓扑速览（2026-08-27）

这里是 Agent 的网络入口。IP 是当日快照；自动化优先使用 MagicDNS/SSH alias，
不要把 100.x 地址复制成第二份配置源。

```text
Internet / GFW
  │ 默认出网
  ▼
hd-1 · dio Mac · macOS · 100.77.236.85
  ├─ mihomo v1.19.30 TUN：普通/AI 出网；显式排除 100.64.0.0/10
  └─ Tailscale Standalone · huodong.work@gmail.com · tail2e95be.ts.net
       └─ hz = ops-1 · Hetzner · 100.125.64.74 · SSH root:2222

Denniffer 的 tailnet
  └─ do = oh · 家庭 Ubuntu · 100.83.72.30 · LAN 192.168.101.24:22
       └─ node share 给 huodong.work@gmail.com：已答应，邀请待发
```

| 节点 | 稳定入口 | 客户端形态 | 当前状态 |
| --- | --- | --- | --- |
| `hd-1`（dio Mac） | `hd-1.tail2e95be.ts.net` | Standalone GUI / System Extension | 当前控制端；旧 `hd`/100.127.191.38 是待删离线节点 |
| `hz`（ops-1） | `hz.tail2e95be.ts.net`；公网 `204.168.246.193:2222` | Linux CLI `tailscaled` / systemd | Mac↔hz WireGuard 直连及 `ssh hz` 已验证 |
| `do`（oh） | tailnet `100.83.72.30`；家庭 LAN `192.168.101.24:22` | Linux CLI `tailscaled`；mihomo 仅显式代理端口 | 当前不在 dio tailnet 视野；等 Denniffer share |

必须维持的边界：

1. Mac 默认流量进 mihomo TUN；`100.64.0.0/10` 从路由层摘除，tailnet 数据面不进代理。
2. MagicDNS `100.100.100.100` 是 `.ts.net` 的 Supplemental resolver；系统主解析仍为
   `1.1.1.1`，其 53 流量由 mihomo DNS hijack 接管。
3. `hz`/`oh` 是服务器，使用登录前在线的 CLI `tailscaled`。`hz` 不接管默认路由；
   `oh` 的 mihomo 不开 TUN，只通过 `127.0.0.1:7890` 服务本机软件。
4. 当前已验证链路只有 Mac↔hz；Mac↔oh 必须等 node share 后再以
   `tailscale ping 100.83.72.30` 和 `ssh oh@100.83.72.30` 验收。

跨项目详细源：`projects/berth/hosts/ops-1.md`、`projects/berth/hosts/oh.md`。

## TUN 模式与 tailscale 共存(2026-08-27 起)

初版刻意不开 TUN(非 root 进程分流已可用,零路由表/DNS 侵入);切换窗口后
升级为 TUN,对齐 Surge 增强模式的能力层:端口模式抓不到不认系统代理/环境
变量的程序和 UDP,防漏面依赖应用自觉。平衡点是**默认全抓 + 显式摘除** ——
两者不打架,因为摘除项都是精确命中:

1. **`tun.route-exclude-address: [100.64.0.0/10]`** —— tailnet 网段不进 TUN。
   路由最长前缀仲裁下 tailscale 自己的 100.64/10 路由本来也赢,这是双保险;
   实际路由表能看到 mihomo 用 `100/10 + 100.128/9` 把这个洞精确挖开。
2. **MagicDNS 不受影响** —— 100.100.100.100 在被排除的网段里,查询走
   tailscale 网卡,dns-hijack 永远碰不到。GUI 客户端把它挂成 Supplemental resolver,
   只接管 `*.ts.net`,系统主解析不变(CLI 时代的 `--accept-dns=false` 已随变体退役)。
3. **connections API 未观察到 tailscale 自身出站(2026-08-27 实测)** —— 客户端换成
   Standalone System Extension 后,其 WireGuard/STUN/DERP 出站在 connections 表无记录、
   ping 直连、STUN 反射为真实公网 IP。曾有的 `PROCESS-NAME,tailscaled,DIRECT`
   顶部规则随 CLI 变体退役(tpl 内留有回退与重新验收说明)。

DNS 接管对齐 Surge:系统 DNS 指 1.1.1.1 → TUN 层 dns-hijack 拦截 → 国内域名
阿里/腾讯 DoH,污染域名 fallback 到 1.1.1.1/8.8.8.8 DoH(`respect-rules` 让
境外 DoH 经节点出站,否则直连被 reset,fallback 形同虚设)。顶层
`ipv6: true` 只为铺 v6 路由捕获硬编码 v6(en0 有移动全局 v6 + v6 默认路由,
是最真实的旁路通道);应用解析侧 `dns.ipv6: false` 回 AAAA 空应答,逼 v4。
实测:境外 v6 字面量进 TUN 后经节点 fail-closed(节点无 v6,不漏);国内
v6 直连正常。

代价:TUN 后 mihomo 是全网单点(root LaunchDaemon KeepAlive 兜底,进程挂 =
断网,恢复靠 launchd 自动重启)。Surge 是系统托管的 System Extension,没有
这个风险 —— 这是两边最后剩下的架构差异。

## 排查

四维度(进程/host/命中规则/出口链)两个面全覆盖,都在本机:

```sh
# 实时连接表:每条连接带进程、规则、完整出口链(chains 逆序 = 流量路径)
curl -s http://127.0.0.1:9090/connections | jq '.connections[] | {host: .metadata.host,
  proc: .metadata.process, rule: (.rule + "/" + .rulePayload), chains: (.chains|reverse)}'

# match 日志:一行一条,含进程归因与命中规则
tail -f ~/.config/mihomo/daemon.out.log | grep --line-buffered match

# 路由体检:TUN 覆盖面全在,100/10 与 100.128/9 之间不该出现 utun4(那是 tailnet 的洞)
netstat -rn -f inet | grep utun4
```

全网断的排查顺序:① `launchctl print system/com.celados.mihomo` 看 state/pid
(crash-loop 时 launchd 有 10s 节流);② `tail daemon.err.log` 看配置错误;
③ 应急先恢复 DNS:`sudo networksetup -setdnsservers Wi-Fi Empty` —— 系统
DNS 指着 1.1.1.1,mihomo 不在线时它不可达,等于没有任何解析。

## tailscale 实装（2026-08-25）
历史:2026-08-25 首装 brew formula(CLI tailscaled v1.102.3,root LaunchDaemon 常驻,
`--accept-dns=false`),设备 `hd` = 100.127.191.38。2026-08-27 迁移至 Standalone GUI
(理由见下),CLI 服务已停、formula 已卸载。

变体选型（2026-08-27 复议，2026-08-25 初选 tailscaled 系误判后修正）：hd 是**随行交互机**
（人带着走、FileVault 解锁使"无人值守重启恢复"不成立），按官方默认推荐迁 **Standalone**
（System Extension）：保留 exit-node **客户端资格**与完整 Taildrop。注意"借家里 oh 出口"
只是客户端侧的选项开通,成路还需 oh 侧 `--advertise-exit-node` 且在其管理台获批准,
两者当前均未验证。tailscaled（CLI/utun）归位给 oh 这类真正的无值守服务器。
迁移已于 2026-08-27 执行。新节点 `hd-1` = 100.77.236.85（MagicDNS
`hd-1.tail2e95be.ts.net`；`hd` 名被旧节点占用，控制台删除旧 `hd` 后可改回）。
Standalone Settings 的 Command Line Integration 已显示安装成功。本机同时存在
`/usr/local/bin/tailscale` 与 `/opt/homebrew/bin/tailscale` 两份内容、时间一致的 launcher，
均转发到 app bundle；保留现状。普通 shell 的 `status`/`version` 已实跑通过，官方
`/usr/local/bin` 入口也已在干净环境中以 `TAILSCALE_BE_CLI=1` 实跑通过。macOS
非交互脚本必须显式设置该变量；相关项目脚本中没有受影响的 Mac 侧调用点。
实测：MagicDNS 以 Supplemental resolver 挂载，仅接管 `*.ts.net`，系统主解析仍为
mihomo 的 1.1.1.1；mihomo connections API 未观察到客户端自身出站（"共存"第 3 条）。
同日 ops-1（Hetzner，tailnet 节点名 `hz`）= 100.125.64.74 加入同 tailnet，
Mac↔hz 直连验证通过；旧 `hd` 节点成离线孤儿，待控制台手动删除。
依据:官方 variants 表
https://tailscale.com/docs/concepts/macos-variants (2026-01-05 校验)。
netcheck `UDP: false` 曾持续数日:推断是 Surge System Extension 拦了 STUN,
走 DERP 中继兜底。2026-08-27 Surge 退场 + TUN 上线后复测:
`UDP: true`、`MappingVariesByDestIP: false`、UPnP 可用,直连能力恢复。

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

**anytls 出站已验证**(2026-08-27,Surge 退场后):嵌套 EOF 消失,gstatic 204、
出口 IP 154.92.x、Anthropic/GoogleAI 全到达;lore push(lore.celados.com:41337)
经 TUN 按 DomainSuffix 规则 DIRECT,实时往返成功;国内直连(baidu 0.3s)不受影响。

## 还缺什么

- **GUI**:TUN 模式下不再需要 —— L3 接管一切,没有系统代理开关的诉求,
  裸 CLI + LaunchDaemon 即可。
- **iOS**：mihomo 没有官方 iOS 客户端。若 iPhone 上还在用 Surge，这条不是配置能解决的。
