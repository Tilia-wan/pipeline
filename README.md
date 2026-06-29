# Cangjie CI unit-test pipeline

A minimal Cangjie (仓颉) project plus a GitHub Actions workflow that:

1. Provisions the Cangjie SDK (one of: a pre-installed `CANGJIE_HOME` action variable, a URL pointed to by the `CANGJIE_SDK_TARBALL_URL` secret, or any other path you wire up).
2. Activates the SDK environment via `envsetup.sh`.
3. Builds the project with `cjpm`.
4. Runs the unit tests with `cjpm test`.

## Project layout

```
.
├── cjpm.toml                # module manifest (name = "pipeline")
├── src/pipeline/
│   ├── main.cj              # program entry point
│   ├── calc.cj              # code under test
│   └── calc_test.cj         # unit tests (file name *_test.cj)
└── .github/workflows/
    └── cangjie-unittest.yml # CI pipeline
```

`cjpm` auto-discovers `*_test.cj` files in the source tree and compiles them
in test mode when `cjpm test` is run. Test functions are top-level functions
marked with the `@Test` macro and use `@Expect` for assertions. No `import` of
`std.unittest` is required — the framework and macros are part of the `std`
module and resolve automatically.

## Wiring up the SDK

The official Cangjie SDK is distributed via
<https://cangjie-lang.cn/download> behind an interactive download flow, so the
workflow does **not** hard-code a download URL. Pick the option that fits your
environment:

| Option | How | Notes |
|---|---|---|
| Pre-installed SDK image | Set repo or org variable `CANGJIE_HOME` (e.g. `/opt/cangjie`). | Use a self-hosted runner or a custom image that already contains the SDK. |
| Public/internal tarball | Set secret `CANGJIE_SDK_TARBALL_URL`. | The workflow `curl`s and untars the archive. Cache the file on your CDN for speed. |
| Manual / OIDC-protected bucket | Replace the `Locate Cangjie SDK` step. | Use `aws s3 cp`, `az storage blob download`, or similar with proper auth. |

After provisioning, `envsetup.sh` is sourced and `cjc -v` / `cjpm --version`
are echoed for traceability.

## Running locally

```bash
tar -xzf cangjie-sdk-linux-x64-1.1.3.tar.gz
source cangjie/envsetup.sh
cjpm build
cjpm test
```

Expected last lines of `cjpm test`:

```
TP: pipeline/pipeline, time elapsed: ..., Result:
    TCS: TestCase_addPositive, ...
    [ PASSED ] CASE: addPositive
    ...
    Summary: TOTAL: 5
    PASSED: 5, SKIPPED: 0, ERROR: 0
    FAILED: 0
```
