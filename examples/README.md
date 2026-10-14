# 示例运行指南

在模块根目录运行：

```sh
moon run examples/mono --target wasm-gc
moon run examples/stereo --target wasm-gc
moon run examples/surround --target wasm-gc
moon run examples/batch --target wasm-gc
```

示例均在 MoonBit 中生成确定性信号，不需要音频文件、宿主解码器或网络。它们展示不同下游使用方式，不是 EBU 一致性测试资产。

## 独立参考测量

```sh
moon run examples/reference --target wasm-gc --release
python tools/test_validate_reference.py
python tools/validate_reference.py
```

示例输出原创确定性信号的综合响度、LRA、采样峰值与真峰值，供机器读取。Python 控制器独立生成对应原始 PCM，以本机安装的 FFmpeg `ebur128` 为参照，并运行三个可移植 MoonBit 后端。仓库不分发音频资产或对照工具的二进制。依赖、公式、舍入、容差、退出状态和实测结果见 [验证说明](../docs/validation/README.md)。该验证不是标准认证。

## 独立节目批量质检与计时

```sh
moon run examples/batch --target wasm-gc --release
python tools/test_measure_batch.py
python tools/measure_batch.py
```

四个分别测量的节目展示逐节目质检，再通过公共 `LoudnessAggregator` 汇总，包括低响度、超峰值和静音素材。聚合不是拼接，也不能覆盖单个素材的交付失败。

可选计时控制器先构建一次，再在 `wasm`、`wasm-gc`、`js` 上计时直接启动的产物，检查输出并记录全部观测值；耗时明确包含运行时和进程启动。方法与实际环境见 [批处理说明](../docs/validation/batch.md) 和 [计时结果](../docs/validation/batch-results.md)。
