# 规则集策略

## 文件

| 文件 | 策略组 | 来源 |
|------|--------|------|
| `ruleset/direct.yaml` | DIRECT / 直连 | cn.mrs/private.mrs 未覆盖的补充直连 |
| `ruleset/proxy.yaml` | 小众网站 | multi-hit 漏网代理 + 用户指定小众网站 |

## 收录原则

- 只收多次命中的漏网域名
- 排除一次性误入后已正常分流的
- 排除无法稳定复用的 CDN 哈希域名
- direct / proxy 不允许重叠
- 优先合并为 `DOMAIN-SUFFIX`（二级域）
- 已被官方 `cn.mrs` / `private.mrs` 覆盖的直连域名，不再写入 direct

## 当前统计

- direct: 5（相对 cn.mrs 去重）
- proxy: 88（suffix 28 + exact 60，去宽泛 CDN）
- overlap: 0

## 与官方规则集的分工

1. `private_ip` / `private_domain` → 内网直连
2. `my_direct` → 官方 cn 未覆盖的补充直连
3. 业务规则 / `my_proxy` → 强制策略（含小众网站）
4. `cn_domain` / `cn_ip` → 国内兜底直连
5. `MATCH` → 漏网之鱼

## 最小接入

```yaml
rules:
  - RULE-SET,private_ip,直连,no-resolve
  - RULE-SET,private_domain,直连
  - RULE-SET,my_direct,DIRECT
  - RULE-SET,my_proxy,小众网站
  - RULE-SET,cn_domain,直连
  - RULE-SET,cn_ip,直连
  - MATCH,漏网之鱼
```
