# mihomo-config

旁路由 **Mihomo Smart** 配置 monorepo。

## 目录

```text
mihomo-config/
├── README.md
├── .gitignore
├── config/config.yaml      # 脱敏配置（可直接改后部署）
├── rule/direct.yaml        # 自定义直连规则集
├── rule/proxy.yaml         # 自定义代理 / 小众网站规则集
└── icons/
    ├── policy/             # 策略组图标
    ├── dashboard/          # 面板图标库
    └── used/               # 实际使用中的图标
```

## 规则集锚点（MRS）

配置内统一使用：

```yaml
RulesetIPcidrMrs: &RIM  {type: http, interval: 86400, behavior: ipcidr, format: mrs}
RulesetDomainMrs: &RDM  {type: http, interval: 86400, behavior: domain, format: mrs}
```

官方 geo 规则通过 `<<: *RDM` / `<<: *RIM` 引用。  
自定义规则集 `my_direct` / `my_proxy` 使用 classical yaml：

```yaml
rule-providers:
  my_direct:
    type: http
    interval: 86400
    behavior: classical
    format: yaml
    url: https://gh-proxy.com/raw.githubusercontent.com/clone-fan/mihomo-config/main/rule/direct.yaml
  my_proxy:
    type: http
    interval: 86400
    behavior: classical
    format: yaml
    url: https://gh-proxy.com/raw.githubusercontent.com/clone-fan/mihomo-config/main/rule/proxy.yaml
```

## 快速使用

1. 复制 [config/config.yaml](config/config.yaml)
2. 替换：
   - `REPLACE_ME_AIRPORT_SUBSCRIPTION_URL`
   - `REPLACE_ME_SS_PASSWORD`
   - 网卡 / 端口
3. 部署到 mihomo smart 内核

## 规则统计

| 文件 | 用途 | 条数 |
|------|------|------|
| rule/direct.yaml | 直连补齐 | 5 |
| rule/proxy.yaml | 代理 / 小众网站 | 88 |

原则：只收多次命中式域名；可合并为 DOMAIN-SUFFIX；direct/proxy 无重叠。

## 规则顺序（关键）

1. private_ip / private_domain
2. 海外 DNS /32 → 默认代理
3. gamedownload_direct + my_direct → DIRECT
4. QUIC / Adobe 拒绝
5. 谷歌 play（含 `services.googleapis.cn`，必须在 cn_* 前）
6. 业务 ruleset
7. my_proxy → 小众网站
8. geolocation!cn_domain
9. IP ruleset
10. cn_domain / cn_ip
11. MATCH → 漏网之鱼

## 图标

```text
https://gh-proxy.com/raw.githubusercontent.com/clone-fan/mihomo-config/main/icons/policy/
```

## 安全

仓库不放真实订阅、密码、token。

## License

仅供个人使用。
