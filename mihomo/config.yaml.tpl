# mihomo on Mac — 从 Surge Merged.conf 迁移而来。渲染与部署见同目录 README.md。
#
# 语义对照的源头是 `surge/config/default.ts`(本地未跟踪,真实副本在 Surge Profiles 下)。
# 那份 TS 配置 + surge-merge 构建工具在这里不再需要:节点前缀、跨源聚合、订阅刷新
# 都由内核原生完成,这份 YAML 是手写的最终态,没有构建步骤。
#
# 渲染: hq secret.render "{ file: 'mihomo/config.yaml.tpl' }"
# 安装: cp mihomo/config.yaml ~/.config/mihomo/config.yaml
# 跑起来: mihomo -d ~/.config/mihomo

mixed-port: 7890
mode: rule
log-level: info
# 顶层开 v6 仅仅是为了让 TUN 铺 v6 路由、捕获硬编码 v6 地址的漏网流量
# (en0 有中国移动全局 v6 + v6 默认路由,是最真实的旁路通道)。应用解析侧
# 仍由 dns.ipv6: false 回 AAAA 空应答,逼流量走 v4。
ipv6: true

# 本机自用,不对外开放。Surge 侧的 skip-proxy(127/192.168/10/172.16/100.64) 在这里
# 由 rules 段的 GEOIP,private + tailnet 两条覆盖,不需要单独的 bypass 列表。
allow-lan: false

external-controller: 127.0.0.1:9090

# 浏览器自带 DoH 会把域名解析成纯 IP,绕过 dns.ipv6:false 与域名规则。
# 三个强制项缺一不可:force-dns-mapping 覆盖 redir-host 流量;
# parse-pure-ip 嗅探无域名连接;override-destination 用 TLS/QUIC SNI 替换
# 原始 IP(尤其是无 v6 网络上的 AAAA),再由 dns.ipv6:false 解析成 v4。
sniffer:
  enable: true
  force-dns-mapping: true
  parse-pure-ip: true
  override-destination: true
  sniff:
    TLS:
      ports: [443]
    QUIC:
      ports: [443]

# TUN:接管全局路由(L3),对齐 Surge 增强模式的能力层 —— 不认系统代理/环境
# 变量的程序、UDP、硬编码 IP 全部捕获,防漏不再依赖应用自觉。与 tailscale
# 共存靠三层显式排除(路由最长前缀仲裁,详见 README):
#   1. route-exclude-address 摘出 tailnet 网段 —— 100.64/10 比 0/1 更具体,
#      tailscale 自己的路由本来就赢,这是双保险;
#   2. MagicDNS(100.100.100.100) 在同网段,不进 TUN,永不被 dns-hijack 劫持;
#   3. tailscale 自身出站(Standalone System Extension 客户端):2026-08-27 实测
#      mihomo connections API 未观察到该流量,ping 直连且 STUN 反射为真实公网 IP,
#      因此当前无需进程规则;回退 CLI tailscaled 时须恢复 DIRECT 后重新验收。
# stack=mixed 是官方文档建议值:TCP system 栈稳、UDP gvisor 栈兼容。
# macOS 上 dns-hijack 劫持不了发往局域网的 DNS,所以系统 DNS 必须指向
# 非 LAN 地址(值无所谓,53 端口一律在 TUN 层被拦),见 README 切换步骤。
tun:
  enable: true
  stack: mixed
  auto-route: true
  auto-detect-interface: true
  dns-hijack:
    - any:53
    - tcp://any:53
  route-exclude-address:
    - 100.64.0.0/10

# 进程匹配。strict = 由内核判断是否开启。端口模式(非 root)实测就能拿进程路径;
# TUN 模式下以 root 运行,全量连接都能归因进程,PROCESS-PATH-WILDCARD 照常。
find-process-mode: strict

# geodata 由 berth 目录复制而来,不让内核自己下载。
# mihomo 会阻塞在 geodata 下载上直到成功才开始监听,失败还会留下截断的 .dat ——
# 这条教训来自 oh 的部署,见 projects/berth/systemd/mihomo/README.md。
geodata-mode: true
geo-auto-update: false

# DNS。原则沿用 Surge 侧的两条教训:
#   1. 别用系统 resolver —— 本地路由器对部分域名(.md ccTLD)返回空答案,
#      解析失败发生在建立隧道之前,换任何出口都救不了;
#   2. 国内 DoH(阿里/腾讯)解析国内域名又快又准,但被污染域名拿不到干净
#      结果,必须有境外兜底 —— Surge 靠自己的 DoH 分流,这里的等价物是 fallback。
#
# redir-host(真实 IP):行为最接近 Surge 增强模式;fake-ip 更快但给应用假地址,
# 对自带解析器/QUIC 的程序有额外坑,dogfood 阶段求稳。
#
# respect-rules:mihomo 自身的 DoH 出站走路由规则 —— 境外 DoH 命中代理规则经
# 节点出去;不开的话境外 DoH 直连被 reset,fallback 形同虚设。不能与 prefer-h3 同开。
#
# fallback 配置后默认启用 fallback-filter(geoip-code CN):nameserver 结果是
# 国内 IP 直接采用,否则采用 fallback 结果。fallback 用纯 IP 的 DoH,免去
# default-nameserver 自举解析境外域名的死锁。
#
# 不设 `listen:` —— DNS 由 TUN 层 dns-hijack 导入,不对外监听;tailscale
# MagicDNS(100.100.100.100)不经 TUN,互不干扰。
dns:
  enable: true
  ipv6: false
  prefer-h3: false
  enhanced-mode: redir-host
  respect-rules: true
  # 代理节点域名只走国内 DoH:机场节点域名国内可解析,同时避免
  # "连节点要先解析节点域名,解析却要经节点"的自锁。
  proxy-server-nameserver:
    - https://223.5.5.5/dns-query
  nameserver:
    - https://223.5.5.5/dns-query
    - https://doh.pub/dns-query
  fallback:
    - https://1.1.1.1/dns-query
    - https://8.8.8.8/dns-query
  # DoH 握手本身要先解析域名,这里给的是纯 IP,不构成自举死锁。
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29

# ============================================================================
# 订阅
# ============================================================================
#
# 当前指向从 oh 拷来的已解析快照(避开机场的一次性闸门,先把分流跑通)。
#
# 切回在线订阅时替换成下面这段 —— URL 在 Vaultwarden
# `机场订阅 (Clash) — tackinessann` (9ca7d6c0-8234-4d61-bd40-6cc340ea9326):
#
#   airport:
#     type: http
#     url: "<订阅 URL>"
#     path: ./providers/airport.yaml
#     interval: 86400          # 机场有一次性闸门,定时刷新无意义,当显式动作做
#     proxy: DIRECT            # 别用机场节点拉机场订阅,节点全挂时会自锁
#     header:
#       User-Agent: ["clash.meta/v1.19.29"]
#
# 刷新是显式动作:先去机场后台点开订阅(10 分钟窗口),再
#   curl -X PUT http://127.0.0.1:9090/providers/proxies/airport
proxy-providers:
  airport:
    type: file
    path: ./providers/airport.yaml
    # 节点名加前缀,对应 Surge 侧 sources[].prefix: "CD"。
    # 加第二家机场时给它另一个前缀,下面的组不用改 —— filter 匹配的是地区关键字。
    override:
      additional-prefix: "CD-"
    health-check:
      enable: true
      url: https://www.gstatic.com/generate_204
      interval: 300
      timeout: 5000
      lazy: true
      expected-status: 204

# ============================================================================
# 直连代理库 (AI 出口)
# ============================================================================
proxies:
  # Webshare 家宽住宅 IP。AI 服务对机房 IP 的风控比住宅 IP 严,这是直连出口。
  - name: s22
    type: http
    server: "{{ bw://3e033f2a-2fbc-49cc-aa01-c793a62cb42d/server }}"
    port: 5669
    username: "{{ bw://3e033f2a-2fbc-49cc-aa01-c793a62cb42d/username }}"
    password: "{{ bw://3e033f2a-2fbc-49cc-aa01-c793a62cb42d/password }}"

  # 链式:s22 的连接本身经由 AI-Relay-JP 建立。
  # 落地仍是 s22 的家宽 IP(目标站看到的),但出境走机场日本节点。
  # 精确对应 Surge 的 `underlying-proxy=AI-Relay-JP`;和那边一样,dialer-proxy
  # 的值可以是策略组名而不只是单个节点。
  - name: s22-via-JP
    type: http
    server: "{{ bw://3e033f2a-2fbc-49cc-aa01-c793a62cb42d/server }}"
    port: 5669
    username: "{{ bw://3e033f2a-2fbc-49cc-aa01-c793a62cb42d/username }}"
    password: "{{ bw://3e033f2a-2fbc-49cc-aa01-c793a62cb42d/password }}"
    dialer-proxy: AI-Relay-JP

# ============================================================================
# 策略组
# ============================================================================
proxy-groups:
  # ---- 中转池 ----
  #
  # AI-Relay-JP 与 CD-JP 当前成员完全相同(只有一家机场),差别在扩展语义:
  #   AI-Relay-JP  include-all-providers → 加第二家机场后自动跨源聚合
  #   CD-JP        use: [airport]        → 永远只含 CD 一家,用于手动锁定运营商
  # 对应 Surge 侧的 relays(跨源) vs topLevelGroups.aggregate.sources(限定源)。
  - name: AI-Relay-JP
    type: url-test
    include-all-providers: true
    filter: "日本"
    url: https://www.gstatic.com/generate_204
    interval: 600
    tolerance: 50

  - name: CD-JP
    type: url-test
    use: [airport]
    filter: "日本"
    url: https://www.gstatic.com/generate_204
    interval: 600
    tolerance: 50

  # ---- AI 分流组 ----
  #
  # 成员顺序 = Surge 侧 outletOrder,select 组默认选中第一个。
  # Claude 默认 direct s22(稳定);Codex/Grok/GoogleAI 默认 relayOnly —— 链式抖动
  # 过,不当默认。GoogleAI 若报 "location is not supported",手动切到 s22。
  - name: Claude
    type: select
    proxies: [s22, s22-via-JP, AI-Relay-JP, CD-JP]

  - name: Codex
    type: select
    proxies: [AI-Relay-JP, s22, s22-via-JP, CD-JP]

  - name: Grok
    type: select
    proxies: [AI-Relay-JP, s22, s22-via-JP, CD-JP]

  - name: GoogleAI
    type: select
    proxies: [AI-Relay-JP, s22, s22-via-JP, CD-JP]

  - name: AI-Misc
    type: select
    proxies: [s22, s22-via-JP, AI-Relay-JP, CD-JP]

  # ---- 通用池 ----
  - name: Best
    type: url-test
    include-all-providers: true
    filter: "香港|日本|新加坡|狮城"
    url: https://www.gstatic.com/generate_204
    interval: 600
    tolerance: 50

  - name: CD
    type: url-test
    use: [airport]
    filter: "香港|日本|新加坡"
    url: https://www.gstatic.com/generate_204
    interval: 600
    tolerance: 50

  - name: Proxy
    type: select
    proxies: [Best, CD, Claude, Codex, Grok, GoogleAI, AI-Misc, DIRECT]

# ============================================================================
# 规则集
# ============================================================================
#
# 全部沿用 Surge 侧的 URL,格式都是 classical(带规则类型前缀的文本)。
# HotKids 那三个含 `USER-AGENT,...` —— mihomo 不支持该类型,实测是 warning 跳过
# 单行,provider 其余规则正常加载,不影响启动。
#
# proxy: Proxy —— 其中 raw.githubusercontent.com 国内直连不通。provider 的 proxy
# 字段直接指定出口,不再过 rules,所以不构成循环依赖。
rule-providers:
  YouTube:      { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/YouTube.list,      url: "https://rawstatic.com/ACL4SSR/ACL4SSR/master/Clash/Ruleset/YouTube.list" }
  Netflix:      { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/Netflix.list,      url: "https://rawstatic.com/HotKids/Rules/master/Surge/RULE-SET/Netflix.list" }
  Google:       { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/Google.list,       url: "https://rawstatic.com/blackmatrix7/ios_rule_script/master/rule/Clash/Google/Google.list" }
  Telegram:     { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/Telegram.list,     url: "https://rawstatic.com/ACL4SSR/ACL4SSR/master/Clash/Telegram.list" }
  Twitter:      { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/Twitter.list,      url: "https://rawstatic.com/blackmatrix7/ios_rule_script/master/rule/Clash/Twitter/Twitter.list" }
  Facebook:     { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/Facebook.list,     url: "https://rawstatic.com/blackmatrix7/ios_rule_script/master/rule/Clash/Facebook/Facebook.list" }
  TikTok:       { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/TikTok.list,       url: "https://rawstatic.com/blackmatrix7/ios_rule_script/master/rule/Clash/TikTok/TikTok.list" }
  Steam:        { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/Steam.list,        url: "https://rawstatic.com/blackmatrix7/ios_rule_script/master/rule/Clash/Steam/Steam.list" }
  Epic:         { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/Epic.list,         url: "https://rawstatic.com/blackmatrix7/ios_rule_script/master/rule/Clash/Epic/Epic.list" }
  Xbox:         { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/Xbox.list,         url: "https://rawstatic.com/blackmatrix7/ios_rule_script/master/rule/Clash/Xbox/Xbox.list" }
  PlayStation:  { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/PlayStation.list,  url: "https://rawstatic.com/blackmatrix7/ios_rule_script/master/rule/Surge/PlayStation/PlayStation.list" }
  HBOMax:       { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/HBO_Max.list,      url: "https://rawstatic.com/HotKids/Rules/master/Surge/RULE-SET/HBO_Max.list" }
  DisneyPlus:   { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/DisneyPlus.list,   url: "https://www.naiixi.com/DisneyPlus.list" }
  Bilibili:     { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/Bilibili.list,     url: "https://rawstatic.com/HotKids/Rules/master/Surge/RULE-SET/Bilibili.list" }
  Microsoft:    { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/Microsoft.list,    url: "https://rawstatic.com/ACL4SSR/ACL4SSR/master/Clash/Microsoft.list" }
  AppleACL:     { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/AppleACL.list,     url: "https://rawstatic.com/ACL4SSR/ACL4SSR/master/Clash/Apple.list" }
  ProxyLite:    { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/ProxyLite.list,    url: "https://rawstatic.com/ACL4SSR/ACL4SSR/master/Clash/ProxyLite.list" }
  LSPrivate:    { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/private.txt,       url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/surge-rules@release/ruleset/private.txt" }
  LSDirect:     { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/direct.txt,        url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/surge-rules@release/ruleset/direct.txt" }
  LSApple:      { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/apple.txt,         url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/surge-rules@release/ruleset/apple.txt" }
  LSiCloud:     { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/icloud.txt,        url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/surge-rules@release/ruleset/icloud.txt" }
  ChinaIPs:     { type: http, behavior: classical, format: text, interval: 86400, proxy: Proxy, path: ./rules/ChinaIPs.list,     url: "https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/ChinaIPs/ChinaIPs.list" }

# ============================================================================
# 规则 (顺序与 Surge Merged.conf 的 [Rule] 段一致)
# ============================================================================
rules:
  # ---- 本机 / 内网 / tailnet ----
  # tailscale 客户端自身的 WireGuard/STUN/DERP 出站:2026-08-27 切换 Standalone
  # (System Extension)后,mihomo connections API 未观察到该流量,ping hz 直连且
  # STUN 反射为真实公网 IP,因此当前无需进程规则。回退 CLI tailscaled 变体时
  # 不沿用这一结论:先恢复进程级 DIRECT,再重新验收。
  # 对应 Surge 的 skip-proxy + RULE-SET,LAN。tailnet 兜底两条:100.64/10 已被
  # route-exclude-address 摘出,这里保证万一有人把 http_proxy 指过来访问 100.x,
  # 不会被卷进代理。
  - GEOSITE,private,DIRECT
  - GEOIP,private,DIRECT,no-resolve
  - IP-CIDR,100.64.0.0/10,DIRECT,no-resolve
  - DOMAIN-SUFFIX,ts.net,DIRECT

  # ---- AI Bypass (必须在 PROCESS 规则之前) ----
  # fish 里的 claude-* 变种(claude-deepseek/bailian/kimi)用的是同一个 claude 进程,
  # 会被下面的 PROCESS 规则抓去走 s22。国内网关从美国家宽访问 = 慢/失败/风控,
  # 所以这些域名必须先行截胡。
  - DOMAIN-SUFFIX,deepseek.com,DIRECT
  - DOMAIN-SUFFIX,aliyuncs.com,DIRECT
  - DOMAIN-SUFFIX,kimi.com,DIRECT
  - DOMAIN-SUFFIX,bigmodel.cn,DIRECT
  - DOMAIN-SUFFIX,moonshot.cn,DIRECT
  - DOMAIN-SUFFIX,volces.com,DIRECT
  - DOMAIN-SUFFIX,siliconflow.cn,DIRECT
  - DOMAIN-SUFFIX,baidubce.com,DIRECT
  # 自建基础设施(ops-1: lore/vault/clickhouse/netdata)。lore push 走 QUIC(UDP 41337),
  # 经代理节点转发 UDP 不可靠 —— Surge 侧那次 udp-policy-not-supported 静默丢包排了
  # 半天。mihomo 没有 udp-policy-not-supported-behaviour 这个兜底开关,这条 DIRECT
  # 就是唯一防线,别删。
  - DOMAIN-SUFFIX,celados.com,DIRECT

  # ---- 进程规则 ----
  # Surge 的 PROCESS-NAME 同时吃进程名和路径;mihomo 分成了两个类型:
  #   带通配符 → PROCESS-PATH-WILDCARD (只支持 * 和 ?)
  #   完整路径 → PROCESS-PATH
  - PROCESS-PATH-WILDCARD,/Users/dio/.local/share/claude/versions/*,Claude
  # codex 不做进程规则:OpenAI 域名可枚举、封号宽松,域名层(openai/chatgpt/
  # oaistatic/oaicdn/oaiusercontent)已闭环。进程层只在 Anthropic 那种"未知
  # 遥测域走错出口就封号"的场景才值得付维护成本——codex 旧三条路径规则就因
  # 安装器迁移静默失效过(2026-08-27 取证后删)。
  # ~/.grok/bin/grok 是符号链接,实际执行的是 downloads/grok-{version}-*
  - PROCESS-PATH-WILDCARD,/Users/dio/.grok/downloads/*,Grok

  # ---- 域名规则 ----
  - DOMAIN-SUFFIX,anthropic.com,Claude
  - DOMAIN-SUFFIX,claude.ai,Claude
  - DOMAIN-SUFFIX,claude.com,Claude
  - DOMAIN-SUFFIX,datadoghq.com,Claude          # Claude Code 的遥测走 datadog

  - DOMAIN-SUFFIX,openai.com,Codex
  - DOMAIN-SUFFIX,chatgpt.com,Codex
  # 浏览器 ChatGPT 场景的静态/内容域,与主域同出口,避免同账号出口身份割裂
  - DOMAIN-SUFFIX,oaistatic.com,Codex
  - DOMAIN-SUFFIX,oaicdn.com,Codex
  - DOMAIN-SUFFIX,oaiusercontent.com,Codex

  - DOMAIN-SUFFIX,x.ai,Grok                     # OAuth(auth) + API(api) + OIDC discovery
  - DOMAIN-SUFFIX,grok.com,Grok                 # 推理代理 / 会话同步 / 头像

  # Antigravity also uses Cloud Run hosts such as *-antigravity-*.run.app;
  # wildcard matching catches those without routing every Cloud Run service.
  - DOMAIN-WILDCARD,*antigravity*,GoogleAI
  - DOMAIN-SUFFIX,antigravity.google,GoogleAI
  - DOMAIN-SUFFIX,antigravity-unleash.goog,GoogleAI
  # Covers cloudcode-pa, daily-cloudcode-pa.sandbox, Gemini API, and OAuth;
  # new Google API subdomains should keep the same egress identity by default.
  - DOMAIN-SUFFIX,googleapis.com,GoogleAI
  # OAuth 必须和 cloudcode-pa 同出口,否则 Google 风控会拒绝 token
  - DOMAIN-SUFFIX,aistudio.google.com,GoogleAI
  - DOMAIN-SUFFIX,gemini.google.com,GoogleAI
  - DOMAIN-SUFFIX,ai.google.dev,GoogleAI

  # 出口身份核验用的 IP 查询 / 风控评分站
  - DOMAIN-SUFFIX,ipinfo.io,AI-Misc
  - DOMAIN-SUFFIX,scamalytics.com,AI-Misc
  - DOMAIN-SUFFIX,ipqualityscore.com,AI-Misc
  - DOMAIN-SUFFIX,iphub.info,AI-Misc
  - DOMAIN-SUFFIX,whoer.net,AI-Misc
  - DOMAIN-SUFFIX,ip2location.com,AI-Misc
  - DOMAIN-SUFFIX,ip2location.io,AI-Misc
  - DOMAIN-SUFFIX,bgp.he.net,AI-Misc
  - DOMAIN-SUFFIX,spamhaus.org,AI-Misc
  - DOMAIN-SUFFIX,abuseipdb.com,AI-Misc

  # ---- 规则集 ----
  - RULE-SET,YouTube,Proxy
  - RULE-SET,Netflix,Proxy
  - RULE-SET,Google,Proxy
  - RULE-SET,Telegram,Proxy
  - RULE-SET,Twitter,Proxy
  - RULE-SET,Facebook,Proxy
  - RULE-SET,TikTok,Proxy
  - RULE-SET,Steam,Proxy
  - RULE-SET,Epic,Proxy
  - RULE-SET,Xbox,Proxy
  - RULE-SET,PlayStation,Proxy
  - RULE-SET,HBOMax,Proxy
  - RULE-SET,DisneyPlus,Proxy
  - RULE-SET,Bilibili,DIRECT
  - RULE-SET,Microsoft,Proxy
  - RULE-SET,AppleACL,DIRECT
  - RULE-SET,ProxyLite,Proxy
  - RULE-SET,LSPrivate,DIRECT
  - RULE-SET,LSDirect,DIRECT
  - RULE-SET,LSApple,DIRECT
  - RULE-SET,LSiCloud,DIRECT
  - RULE-SET,ChinaIPs,DIRECT

  - GEOIP,CN,DIRECT
  - MATCH,Proxy
