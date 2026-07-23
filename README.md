# mihomo-config

个人用 **Mihomo Smart** 配置与自定义规则 monorepo。

当前公开模板已与运行机 `10.0.0.2` 的 `/etc/mihomo/config.yaml` 对齐（密钥已脱敏）。

## 目录结构

```text
mihomo-config/
├── README.md
├── .gitignore
├── config/config.yaml      # 脱敏后的可运行模板（顺序 / no-resolve 与线上一致）
├── rule/proxy.yaml         # 自定义代理 / 小众网站 domain 文本源
├── rule/proxy.mrs          # 代理 MRS，供 RDM 引用
└── icons/
    ├── policy/             # 策略组图标
    └── dashboard/          # 面板图标
```

## 规则集写法（MRS + RDM）

锚点：

```yaml
RulesetIPcidrMrs: &RIM  {type: http, interval: 86400, behavior: ipcidr, format: mrs}
RulesetDomainMrs: &RDM  {type: http, interval: 86400, behavior: domain, format: mrs}
```

自定义规则集：

```yaml
rule-providers:
  my_proxy: { <<: *RDM, url: 'https://gh-proxy.com/raw.githubusercontent.com/clone-fan/mihomo-config/main/rule/proxy.mrs' }
```

说明：

- `rule/proxy.yaml` 是 domain 文本源，方便阅读与维护
- `rule/proxy.mrs` 是运行时格式，config 只引用 MRS
- domain 写法：`example.com` 精确，`+.example.com` 后缀
- 当前不再维护 `my_direct` / `direct.yaml`

## 规则条数

| 文件 | 用途 | domain 约数 |
|------|------|-------------|
| rule/proxy.yaml + proxy.mrs | 自定义代理 / 小众网站 | 88 |

## 当前 rules 关键点（与线上一致）

1. `private_ip/private_domain` + 指定 DNS IP（含 `no-resolve`）
2. 下载直连 / QUIC 拒绝 / Adobe 拒绝
3. 业务分流（moviepilot、github、流媒体、社群等）
4. `RULE-SET,my_proxy,小众网站`
5. `geolocation!cn` 与 IP 规则集
6. `cn_domain` / `cn_ip` → `DIRECT`
7. `MATCH,漏网之鱼`

## 使用方式

1. 复制 [config/config.yaml](config/config.yaml)
2. 替换：
   - `REPLACE_ME_AIRPORT_SUBSCRIPTION_URL`
   - `REPLACE_ME_SS_PASSWORD`
   - 按需改端口 / 网卡
3. 使用 mihomo smart 内核加载

## 图标

策略组 icon 已指向本仓库：

```text
https://gh-proxy.com/raw.githubusercontent.com/clone-fan/mihomo-config/main/icons/policy/...
```

## 维护

- 改 domain：先改 `rule/proxy.yaml`，再生成对应 `proxy.mrs`
- 改分流逻辑：同步改运行机 config，再回写本仓库脱敏模板
- 公钥仓库不要提交真实订阅、密码、token
