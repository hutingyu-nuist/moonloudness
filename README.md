# MoonLoudness

MoonLoudness 是一个纯 MoonBit 的流式响度与峰值分析库，输入为交错排列的 PCM 采样。它为媒体质检、批量处理、实时仪表和音频编辑工具提供可复用的进程内测量核心；解码、播放和增益应用仍由调用方负责。

## 安装

模块：**hutingyu-nuist/moonloudness@0.1.1**。在下游 MoonBit 项目中添加依赖：

```sh
moon add hutingyu-nuist/moonloudness
```

无需 MoonCakes 凭据即可使用公开包。请检查依赖清单中实际解析的版本；打包成功不等于已经发布，精确版本的可用性以公开注册表为准。0.1.1 是中文文档补丁，测量算法与公共 API 不变。

也可以直接运行源码：

```sh
git clone https://github.com/hutingyu-nuist/moonloudness.git
cd moonloudness
moon check --target wasm-gc
moon test --target wasm-gc
```

## 支持的测量流程

- 48,000 Hz、按完整帧交错排列的浮点 PCM；单声道（`C`）、立体声（`L,R`）和 5.0（`L,R,C,Ls,Rs`，不含 LFE）。
- 逐声道 K 加权、400 ms 瞬时与 3 s 短时窗口、综合响度门控、响度范围（LRA）、采样峰值和四相 FIR 真峰值估计。
- 修改状态前预检整个输入块：拒绝不完整帧、非有限数值以及绝对值大于 `1e150` 的采样。
- 有界测量历史：默认保留 600 点，可配置为 0～100,000 点；以固定内存聚合已经结束的独立节目报告。
- 可检查的门控阈值与块数、显式 `GateStatus`、独立于分析器状态的版本化 JSON，以及受调用方真峰值上限约束的非破坏性恒定增益建议。
- 同步零拷贝 `push_view`、带校验的独立节目组组合，以及明确的历史与重置契约。

门控与百分位数使用 0.01 LU 直方图桶，阈值保守量化到桶边界，以换取有界内存；它不是任意时长的精确音频块档案。本项目不声称通过 ITU-R BS.1770-5 或 EBU Tech 3341/3342/3343 一致性认证，也未运行 EBU 官方测试套件。

## 快速上手

以下片段在导入本库为 `@moonloudness` 后使用；`samples` 是调用方提供的 `Array[Double]`，包含完整的交错 PCM 帧：

```moonbit
let layout = @moonloudness.ChannelLayout::mono()
let config = match @moonloudness.MeterConfig::new(48000, layout) {
  Ok(value) => value
  Err(_) => panic()
}
let meter = @moonloudness.Analyzer::new(config)
match meter.push(samples) { // Array[Double]，完整交错帧
  Ok(_) => ()
  Err(_) => panic()
}
let report = meter.finish()
match report.integrated_lufs() {
  Some(value) => println(value.to_string())
  None => println("综合响度暂不可用")
}
match report.true_peak_dbtp() {
  Some(value) => println(value.to_string())
  None => println("真峰值暂不可用")
}
```

`Analyzer::push` 接收归一化浮点采样；为了分析峰值余量，也接受 `[-1,1]` 之外、但不超过上述数值上限的有限值。库不包含解码器、容器读取器、重采样器、播放引擎、限幅器，也不会自动应用增益。

## 可运行示例

在模块根目录执行：

```sh
moon run examples/mono --target wasm-gc
moon run examples/stereo --target wasm-gc
moon run examples/surround --target wasm-gc
moon run examples/batch --target wasm-gc
moon run examples/reference --target wasm-gc
```

- `mono`：分析 1 kHz 节目信号并检查增益建议。
- `stereo`：分块输入，读取保留的时间序列与门控诊断。
- `surround`：检查 5.0 布局的声道标签、权重和逐声道峰值。
- `batch`：先逐节目质检，再汇总独立节目；汇总结果不能掩盖单项失败。
- `reference`：输出原创合成信号的测量数据，供独立差分验证使用。

所有示例自行生成信号，不依赖音频文件或网络。更多步骤见 [示例说明](examples/README.md)。

## 检查、构建与测试

```sh
moon info
moon fmt --check
moon check --deny-warn --target wasm-gc
moon check --deny-warn --target js
moon test --deny-warn --target wasm-gc
moon test --deny-warn --target js
moon build --release --target wasm-gc
```

本地 `wasm-gc`、`wasm`、`js` 的 debug 与 release 测试均通过 **67/67**；`native` 的严格检查也通过，但本机 Windows 环境没有 native C 编译器。实际 native 构建、测试及示例由 Ubuntu CI 验证，不能将其视为本地 native 运行结果。保守源码和提交审计命令为 `python tools/audit_delivery.py --strict`：自动检查非空提交、不同源码树与作者，开发价值仍须人工审查。

2026-10-14 的独立工程验证中，五组确定性合成信号、四项指标、三个可移植后端共 **60/60 次比较**通过预先声明的 FFmpeg 回归容差。该结果**不是标准认证**。见 [验证说明](docs/validation/README.md)、[实测结果](docs/validation/reference-results.md) 和 [批处理计时](docs/validation/batch-results.md)。计时包含进程启动和 PCM 生成，不是纯 DSP 运算耗时；仓库不分发外部音频测试资产。

Python 控制器与审计测试：

```sh
python -m unittest discover -s tools -p "test_*.py" -v
```

这些可选控制器仅使用 Python 标准库；FFmpeg 差分验证另需安装 FFmpeg。

## 三类下游场景与数据交换

1. **媒体入库与质检**：已有解码器提供 48 kHz 交错 PCM 块；逐素材保留综合响度、LRA、采样峰值、真峰值和门控诊断，由质检系统按自身规则判定。即使聚合结果看似合格，批处理示例仍保留各素材的失败结果。
2. **实时测量仪表**：通过 `push_view` 输入有界块，读取 `snapshot()` 与按时间排序的历史。400 ms／3 s 窗口需要预热，有限历史不是音频档案；结束时冲刷 FIR 尾部，但不虚增输入帧数。
3. **编辑与峰值余量工具**：分析 mono／stereo／5.0 PCM，检查声道峰值并计算受上限约束的恒定增益建议。由下游决定是否应用，并对输出重新测量；固定门控的预测不能保证归一化后的实际响度。

`report.to_json()` 输出独立的版本化对象，缺失值明确表示为 `null`，见 [JSON 契约](docs/design/report-json.md)。`LoudnessAggregator::add` 与 `merge` 汇总独立节目的分布，而非平均 LUFS，也不会拼接跨节目的滤波器状态。

## 数值边界与非目标

- 有限采样幅度允许至 `1e150`，但高于 +24 LUFS 的候选会令相应直方图门控不可用，而非截断成看似有效的结果。
- 0.01 LU 的桶宽不能保证门控阈值附近的成员选择误差也不超过 0.01 LU。
- 计数器限制单次会话长度：单声道约 12.43 小时、立体声约 6.21 小时、5.0 约 2.49 小时。
- 不支持任意采样率、任意声道映射、LFE／5.1、文件解码、重采样、播放、编码、限幅、动态压缩或自动增益。

详见 [算法、近似与输入约束](docs/design/conformance.md) 和 [工程交付记录](docs/competition/delivery-audit.md)。

## 设计来源、许可与生态查重

设计参考 ITU-R BS.1770-5 和 EBU Tech 3341/3342/3343。Rust `sdroege/ebur128` v0.1.10 的固定提交用于能力参照；未复制或翻译其 Rust 源码。原创实现采用 MIT 许可。来源、第三方归属与 AI 使用说明见 [THIRD_PARTY.md](THIRD_PARTY.md)、[LICENSE](LICENSE) 和 [AI_USAGE.md](AI_USAGE.md)。

有限检索范围内的候选对比与相邻项目源码、API、测试审查见 [查重记录](docs/competition/duplicate-check.md)。结论仅为：**在已记录检索范围内未发现成熟直接替代**，不是对整个生态作绝对不存在的断言。
