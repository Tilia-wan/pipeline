# CI/CD 流水线说明

本文档说明本仓库选用的 CI/CD 方案、搭建过程、踩坑记录与最终结果。

## 一、流水线简介

### 选型

| 维度 | 选型 | 原因 |
|---|---|---|
| 平台 | **GitHub Actions** (`ubuntu-22.04` hosted runner) | 仓库已在 GitHub、无需自建 runner |
| SDK 来源 | **GitHub Release 公开资产** + `CANGJIE_SDK_TARBALL_URL` secret | 仓颉官方下载需交互登录，runner 拉不到；用 Release 做中转最省事 |
| 构建/测试 | 官方 `cjpm 1.1.3` | 项目自带 |
| 测试框架 | `std.unittest` (`@Test` / `@Expect` 宏) | SDK 内置、零依赖 |

### 触发条件

`.github/workflows/cangjie-unittest.yml`:

```yaml
on:
  push:
    branches: [main, master, develop]
  pull_request:
    branches: [main, master]
  workflow_dispatch:
```

### 流水线步骤

```
git push ──► ① Checkout
            ② 安装 runtime 依赖 (binutils / libc-dev / libssl-dev ...)
            ③ Locate Cangjie SDK
                 └─ 从 $CANGJIE_SDK_TARBALL_URL 下载 tarball
                 └─ 解压, find 出 cangjie/ 根目录
            ④ Activate SDK environment
                 └─ source envsetup.sh
                 └─ 注入 cangjie/tools/bin 到 GITHUB_PATH
                 └─ 注入 LD_LIBRARY_PATH 到 GITHUB_ENV
            ⑤ cjpm build
            ⑥ cjpm test
            ⑦ (失败时) 上传 target/** 日志为 artifact
```

## 二、搭建过程关键步骤

### 1. 项目骨架

```
.
├── cjpm.toml                 # src-dir = "src/pipeline"
├── src/pipeline/
│   ├── main.cj               # 程序入口
│   ├── calc.cj               # 被测代码 (add / subtract / multiply)
│   └── calc_test.cj          # 5 个 @Test 用例
└── .github/workflows/
    └── cangjie-unittest.yml  # 流水线
```

`cjpm.toml` 把 `src-dir` 指向 `src/pipeline`，否则 `cjpm` 在 `src/` 下找不到 `.cj` 文件、测试用例 0/0/0。

### 2. 编写 workflow

`.github/workflows/cangjie-unittest.yml` 关键三步:

```yaml
- name: Locate Cangjie SDK
  env:
    CANGJIE_SDK_TARBALL_URL: ${{ secrets.CANGJIE_SDK_TARBALL_URL }}
  run: |
    curl -fsSL -o sdk.tar.gz "${CANGJIE_SDK_TARBALL_URL}"
    tar -xzf sdk.tar.gz
    CANGJIE_HOME="$(find . -mindepth 1 -maxdepth 3 -type d -name cangjie | head -n1)"

- name: Activate SDK environment
  run: |
    source ${CANGJIE_HOME}/envsetup.sh
    echo "${CANGJIE_HOME}/tools/bin" >> "$GITHUB_PATH"
    echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH}" >> "$GITHUB_ENV"

- run: cjpm build
- run: cjpm test
```

### 3. 在 GitHub Release 上传 SDK

仓颉 SDK 1.1.3 Linux x64 tarball (~380 MB) 上传到 Release `v1.0.0`，**保持 Public**，直链形如:

```
https://github.com/Tilia-wan/pipeline/releases/download/v1.0.0/cangjie-sdk-linux-x64-1.1.3.tar.gz
```

### 4. 配置 Secret

Settings → Secrets and variables → Actions → New repository secret:

| Name | Secret |
|---|---|
| `CANGJIE_SDK_TARBALL_URL` | `https://github.com/Tilia-wan/pipeline/releases/download/v1.0.0/cangjie-sdk-linux-x64-1.1.3.tar.gz` |

### 5. 推送触发

```bash
git push origin main
```

## 三、踩坑记录（6 次失败 → 第 6 次成功）

| # | 现象 | 根因 | 修复 |
|---|---|---|---|
| 1 | `No Cangjie SDK available` | step env 没注入 `CANGJIE_SDK_TARBALL_URL` | 显式 `env: CANGJIE_SDK_TARBALL_URL: ${{ secrets.* }}` |
| 2 | `no cjc under tools/bin/ or bin/` | 仓颉 SDK 1.1.3 把 `cjc` 放在 `tools/bin/`，`envsetup.sh` 未把它加入 PATH 时找不到 | `echo "${CANGJIE_HOME}/tools/bin" >> "$GITHUB_PATH"` |
| 3 | `LD_LIBRARY_PATH: unbound variable` | `set -u` 与 `envsetup.sh` 内部未初始化该变量冲突 | 改 `set -eo pipefail`（去掉 `-u`） |
| 4 | `find -name cangjie` 命中父目录 | `$RUNNER_TEMP/cangjie` 父目录本身叫 `cangjie` | 加 `-mindepth 1` |
| 5 | `libcangjie-runtime.so: cannot open` | `LD_LIBRARY_PATH` 只在 source envsetup.sh 的 step 内有效，下游 step 拿不到 | `echo "LD_LIBRARY_PATH=..." >> "$GITHUB_ENV"` |
| 6 | ✅ **5/5 PASSED** | — | — |

### 经验总结

1. **GitHub Actions 的 step 是新 shell**：`source` 与环境变量不会跨 step 持久化，必须显式 `>> $GITHUB_ENV` / `$GITHUB_PATH`。
2. **`envsetup.sh` 不能直接放 `set -u` 下**：仓颉官方脚本会引用未初始化变量 (`LD_LIBRARY_PATH`)，需要 `set -eo pipefail`。
3. **`cjc` 路径**：1.1.3 在 `tools/bin/cjc`，`envsetup.sh` 才会把它放入 PATH；如果直接调用必须显式追加 `tools/bin`。
4. **`find` 路径陷阱**：临时目录与目标目录同名时必须 `-mindepth 1`，否则取到错误父目录。

## 四、最终结果

### 成功的 Actions Run

**链接**: https://github.com/Tilia-wan/pipeline/actions/runs/28401424152

**Status**: ✅ success

### 关键日志

```
Cangjie Compiler: 1.1.3 (cjnative)
Target: x86_64-unknown-linux-gnu
Cangjie Project Manager: 1.1.3

TP: pipeline, time elapsed: 2135993 ns, RESULT:
    TCS: TestCase_addPositive
    [ PASSED ] CASE: addPositive
    TCS: TestCase_addNegative
    [ PASSED ] CASE: addNegative
    TCS: TestCase_subtractBasic
    [ PASSED ] CASE: subtractBasic
    TCS: TestCase_multiplyBasic
    [ PASSED ] CASE: multiplyBasic
    TCS: TestCase_addCommutative
    [ PASSED ] CASE: addCommutative
Summary: TOTAL: 5
    PASSED: 5, SKIPPED: 0, ERROR: 0
    FAILED: 0
```

### 测试用例覆盖

| 用例 | 覆盖点 | 结果 |
|---|---|---|
| `addPositive` | add 正数/0/异号 | ✅ |
| `addNegative` | add 负+负 | ✅ |
| `subtractBasic` | subtract 三种情形 | ✅ |
| `multiplyBasic` | multiply 含 0/负 | ✅ |
| `addCommutative` | add 交换律 | ✅ |

### 仓库最终状态

- **代码**: 5 个 commit 含 bootstrap + 4 处 CI 修复 + 1 处 cjpm 配置修复
- **workflow**: `.github/workflows/cangjie-unittest.yml`
- **Secret**: `CANGJIE_SDK_TARBALL_URL` → 指向 Release `v1.0.0` 公开资产
- **Release**: `v1.0.0` 含 `cangjie-sdk-linux-x64-1.1.3.tar.gz`
- **结果**: 5/5 PASSED，每次 push 都会自动跑

## 五、截图位置指引

在 GitHub 网页上自行截屏的 4 个关键画面:

1. **Actions 总览**: `https://github.com/Tilia-wan/pipeline/actions` → 顶部最新 run 显示 ✅
2. **Run 详情**: `https://github.com/Tilia-wan/pipeline/actions/runs/28401424152` → 7 个 step 全绿
3. **测试输出**: 展开 "Run unit tests" step → `Summary: TOTAL: 5 / PASSED: 5`
4. **Release 页面**: `https://github.com/Tilia-wan/pipeline/releases/tag/v1.0.0` → 资产列表含 SDK tarball
