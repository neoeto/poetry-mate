# data-distribution-api 规格说明

## Purpose

APP 获取作品集清单与数据卷的 HTTP 只读接口(Cloudflare Worker + R2)。

# 数据分发 API（data-distribution-api）

## Requirements

### Requirement: 提供作品集目录接口
服务 SHALL 提供 `GET /api/v1/catalog`，返回全部作品集的清单（标识、名称、简介、分卷数、总体积）及当前全局数据版本号。

#### Scenario: 获取作品集目录
- **WHEN** 客户端请求 GET /api/v1/catalog
- **THEN** 响应 200，body 为 JSON，包含 version 字段与 collections 数组（至少含全唐诗、全宋词等集子）

#### Scenario: catalog 响应启用短缓存
- **WHEN** 查看 catalog 响应头
- **THEN** Cache-Control 表明短周期缓存（分钟级），以便版本切换及时可见

### Requirement: 提供作品集分卷清单接口
服务 SHALL 提供 `GET /api/v1/collections/:id/manifest`，返回该集全部卷的文件名、sha256、字节数与记录数。

#### Scenario: 获取全唐诗的卷清单
- **WHEN** 客户端请求 GET /api/v1/collections/tangshi/manifest
- **THEN** 响应 200，列出该集全部分卷及各自的 sha256 与大小

#### Scenario: 请求不存在的作品集
- **WHEN** 客户端请求 GET /api/v1/collections/notexist/manifest
- **THEN** 响应 404

### Requirement: 提供分卷下载
服务 SHALL 提供 `GET /volumes/:collection/:file`，从 R2 读取对应 zstd 分卷原样返回。

#### Scenario: 下载分卷且内容完整
- **WHEN** 客户端按 manifest 中的路径下载某分卷
- **THEN** 响应 200，响应体的 sha256 与 manifest 登记值一致

#### Scenario: 请求不存在的卷文件
- **WHEN** 客户端请求 manifest 之外的卷路径
- **THEN** 响应 404，不泄露存储内部结构信息

#### Scenario: 分卷响应标记不可变缓存
- **WHEN** 查看分卷下载响应头
- **THEN** Cache-Control 含 max-age≥1 年与 immutable（卷内容按版本目录存放，永不原地修改）

### Requirement: 服务为只读公开接口
分发服务 MUST NOT 要求任何鉴权，MUST NOT 提供任何写操作接口，MUST NOT 经手任何 LLM API 流量。

#### Scenario: 非只读方法被拒绝
- **WHEN** 向任意端点发起 POST/PUT/DELETE 请求
- **THEN** 响应 405 Method Not Allowed

### Requirement: 通过自定义域名提供服务
服务 MUST 绑定自定义域名，MUST NOT 依赖 workers.dev 默认域名作为面向用户的接入地址（国内可达性要求）。

#### Scenario: 自定义域名可用
- **WHEN** 通过自定义域名请求 GET /api/v1/catalog
- **THEN** 返回与服务相同的正确响应

### Requirement: 版本回滚能力
服务 SHALL 支持通过调整 catalog 所指版本指针将全体客户端引导回任意近期版本（保留最近 ≥3 个版本的历史目录），回滚操作不需要重新部署 Worker 代码。

#### Scenario: 切回旧版本
- **WHEN** 新版本数据发现问题时，运维将版本指针改回上一版
- **THEN** 此后 catalog 返回旧版本号，客户端据此下载旧版本分卷
