# mihomo-config

面向旁路由的 **Mihomo Smart 配置 monorepo**。

本仓库统一存放：

- 可发布的配置模板（密钥已脱敏）
- 自定义规则集 `direct` / `proxy`
- 全量图标资源（policy / dashboard）
- 本地校验与配置脱敏脚本

> 旧仓库 `Mihomo_Yaml` 将被废弃；新内容以本仓库为准。

## 快速使用

### 1. 规则集引用

```yaml
rule-providers:
  my_direct:
    type: http
    interval: 86400
    behavior: classical
    format: yaml
    url: https://gh-proxy.com/raw.githubusercontent.com/clone-fan/mihomo-config/main/ruleset/direct.yaml
  my_proxy:
    type: http
    interval: 86400
    behavior: classical
    format: yaml
    url: https://gh-proxy.com/raw.githubusercontent.com/clone-fan/mihomo-config/main/ruleset/proxy.yaml

rules:
  - RULE-SET,my_direct,DIRECT
  - RULE-SET,my_proxy,小众网站
```

### 2. 配置模板

1. 复制 [`config/config.template.yaml`](config/config.template.yaml)
2. 替换：
   - `REPLACE_ME_AIRPORT_SUBSCRIPTION_URL`
   - `REPLACE_ME_SS_PASSWORD`
   - 网卡 / 端口 / 订阅相关本地字段
3. 部署到 mihomo smart 内核

## 目录结构

```text
config/     配置模板
ruleset/    自定义规则集
icons/      全量图标（policy + dashboard）
examples/   最小可用片段
scripts/    脱敏 / 校验
docs/       框架与策略说明
```

## 规则统计

| 文件 | 用途 | 条数 |
|------|------|------|
| `ruleset/direct.yaml` | 直连补漏 | 81 |
| `ruleset/proxy.yaml` | 代理 / 小众网站 | 90 |

仅纳入多次命中的漏网域名；可合并时优先 suffix；direct/proxy 无重叠。  
详见 [docs/RULESET.md](docs/RULESET.md)。

## 图标

本仓库 **全量托管** 图标：

- `icons/policy/`：原 Policy-Icon（策略组图标）
- `icons/dashboard/`：原 dashboard-icons（面板图标库）

配置 icon 基址：

```text
https://gh-proxy.com/raw.githubusercontent.com/clone-fan/mihomo-config/main/icons/policy/
```

详见 [docs/ICONS.md](docs/ICONS.md)。

## 本地校验

```bash
python scripts/validate_repo.py
```

## 文档

- [框架说明](docs/FRAMEWORK.md)
- [规则集策略](docs/RULESET.md)
- [图标策略](docs/ICONS.md)

## 安全

仓库中不放真实订阅、密码、token。本地真实配置请放 `.local.yaml` 或机器私有路径，并被 `.gitignore` 忽略。

## License

仅供个人使用。规则集与模板可按需修改；请勿公开真实密钥。