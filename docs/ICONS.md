# 图标策略

## 当前模式：全量托管

本 monorepo **全量收录**两个图标源：

| 本地路径 | 来源 | 用途 |
|----------|------|------|
| `icons/policy/` | 原 `clone-fan/Policy-Icon` | 策略组彩色图标 + 嵌套 dashboard png |
| `icons/dashboard/` | 原 `clone-fan/dashboard-icons` | 完整面板图标库 |
| `icons/used/` | 可选精选落地 | 以后若要裁剪体积可放这里 |

原独立图标仓库在确认 monorepo 拷贝完整后删除，不再外链依赖。

## 配置引用

策略组 icon 统一指向本仓 raw（经 gh-proxy）：

```text
https://gh-proxy.com/raw.githubusercontent.com/clone-fan/mihomo-config/main/icons/policy/IconSet/Color/Global.png
https://gh-proxy.com/raw.githubusercontent.com/clone-fan/mihomo-config/main/icons/policy/dashboard-icons/png/github.png
```

完整 dashboard 库也可直接引用：

```text
https://gh-proxy.com/raw.githubusercontent.com/clone-fan/mihomo-config/main/icons/dashboard/png/github.png
```

现网 `config.template.yaml` 保持 **Policy-Icon 原有相对路径结构**（`IconSet/...` 与 `dashboard-icons/png/...`），只替换仓库基址，避免逐条改路径。

## 体积说明

- `icons/policy`：约 4.5k 文件 / ~108MB
- `icons/dashboard`：约 11.6k 文件 / ~268MB
- 合计约 16k 文件 / ~376MB

克隆本仓时请预留足够磁盘与时间。

## 维护

1. 增删图标：直接改 `icons/policy` 或 `icons/dashboard`
2. 改策略组图标：编辑 `config/config.template.yaml` 的 `icon:` 字段
3. 本地校验：`python scripts/validate_repo.py`
