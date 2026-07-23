# 规则集策略

## 文件

| 文件 | 策略组 | 来源 |
|------|--------|------|
| `ruleset/direct.yaml` | DIRECT | multi-hit 漏网之鱼中应直连的域名，可合并为 DOMAIN-SUFFIX |
| `ruleset/proxy.yaml` | 小众网站 | multi-hit 应代理域名 + 用户自定义小众网站 |

## 收录原则

只收有多次记录的漏网域名：

- 排除一次性误入后已正常分流的
- 排除明显 CDN 临时哈希域名（无法稳定复用）
- direct / proxy 不允许重叠
- 能安全合并到二级/一级后缀时用 `DOMAIN-SUFFIX`，否则保留 `DOMAIN`

## 当前统计

- direct: 81
- proxy: 90
- overlap: 0

## 用户指定的小众网站（全部进 proxy）

- qichiyu.com
- xxlb.net
- 847977.xyz
- linux.do
- anyrouter.top
- evomap.ai
- 1ms.run
- 42w.shop
- abrdns.com
- de5.net

## 最小接入片段

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

## 更新流程

1. 从 mihomo 漏网之鱼日志抽样
2. 过滤到 multi-hit
3. 人工归类 direct / proxy
4. 合并 suffix，去重
5. 跑 `validate_repo.py`