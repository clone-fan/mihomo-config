# 框架说明

## 目标

`mihomo-config` 是旁路由 Mihomo Smart 的配置 monorepo：

- 可发布配置模板
- 自定义规则集（direct / proxy）
- 全量图标资源（policy / dashboard）
- 本地校验脚本

## 目录

```text
mihomo-config/
├── README.md
├── .gitignore
├── config/
│   └── config.template.yaml
├── ruleset/
│   ├── direct.yaml
│   └── proxy.yaml
├── icons/
│   ├── README.md
│   ├── policy/
│   ├── dashboard/
│   └── used/
├── examples/
│   ├── rules-snippet.yaml
│   └── config.local-file.yaml
├── scripts/
│   ├── sanitize_config.py
│   └── validate_repo.py
└── docs/
    ├── FRAMEWORK.md
    ├── RULESET.md
    └── ICONS.md
```

## 命名

| 名称 | 含义 |
|------|------|
| `mihomo-config` | 仓库名 |
| `my_direct` | 自定义直连规则 provider |
| `my_proxy` | 自定义代理/小众网站 provider |
| `config.template.yaml` | 脱敏后的可发布模板 |
| `ruleset/direct.yaml` | classical payload，直连补漏 |
| `ruleset/proxy.yaml` | classical payload，代理/小众网站 |

## 建议规则顺序

1. 局域网 / DNS IP-CIDR
2. `gamedownload_direct` + `my_direct` → DIRECT
3. QUIC 拒绝、Adobe 拒绝
4. 业务分流：play / moviepilot / github / AI / 流媒体等
5. `my_proxy` → 小众网站
6. `geolocation!cn_domain` → 国外网站
7. IP 分流
8. `MATCH,漏网之鱼`

## 发布后原始地址

- Direct: `https://gh-proxy.com/raw.githubusercontent.com/clone-fan/mihomo-config/main/ruleset/direct.yaml`
- Proxy: `https://gh-proxy.com/raw.githubusercontent.com/clone-fan/mihomo-config/main/ruleset/proxy.yaml`
- 直连 raw: `https://raw.githubusercontent.com/clone-fan/mihomo-config/main/ruleset/direct.yaml`

## 安全边界

禁止进入公开仓库：

- 机场订阅 URL
- 家里 SS 密码
- API token / cookie / 密钥
- 可定位的私人主机口令

## 发布流程

1. 本地改规则 / 模板
2. `python scripts/validate_repo.py`
3. 明确同意后再创建/推送 GitHub 仓库
4. 旧仓库 `Mihomo_Yaml` 仅在你明确同意后处理

## 图标托管

- `icons/policy/`：原 Policy-Icon 全量
- `icons/dashboard/`：原 dashboard-icons 全量
- 配置 icon 基址：`.../mihomo-config/main/icons/policy/`
