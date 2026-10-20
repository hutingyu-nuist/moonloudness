# MoonLoudness 选题与语义查重记录

- 检查/记录日期：2026-10-13
- 选题状态：参赛者已明确选择 MoonLoudness；本文件先于实现落地。
- 项目类型：纯 MoonBit、进程内、可复用的流式音频响度测量库。
- 结论措辞：**在已记录检索范围内未发现成熟直接替代。** 这不是对整个 MoonBit 生态或未来项目的绝对断言。

## 候选筛选摘要

| 顺序 | 候选方向 | 下游用户及可复用闭环 | 最近邻与语义判定 | 决策 |
|---|---|---|---|---|
| 1（推荐并已确认） | **MoonLoudness：EBU R 128 / BS.1770 流式响度分析** | 广播/播客 QC；媒体管线元数据提取；DAW、游戏音频与现场混音监测；测试及音频分析工具。输入 PCM 分块，持续汇总标准化响度/峰值指标供调用方审核或后续自行处理。 | MoonSpectrum、moonbit-dsp、moondsp、mizchi/audio、MoonEcho 等均属音频邻接能力；已记录材料未显示它们提供同一套 K 加权、门控 Integrated、LRA 及 true-peak 报告闭环。不是解码器、播放器或 FFmpeg 命令包装。 | 通过已记录范围内的语义门禁；适合独立建设，核心数据（带声道布局的 PCM 流及响度窗口能量）与相邻频谱、合成、解码、指纹工作流不同。 |
| 2（淘汰） | 通用 terminfo 数据库格式解析/编译 | 终端模拟器、SSH/TUI 客户端及终端工具链可能复用。 | `cstoooo/terminfo` 已覆盖 terminfo 解析/写回、扩展能力和 `tparm` 一类能力展开；数据模型、解析/编译/参数化能力和验收方式与候选重合。 | 直接重合风险，不选。 |
| 3（淘汰） | Cap’n Proto 消息编码/解码基础库 | RPC、消息队列、跨进程或文件消息系统可复用。 | `peter-jerry-ye/capnp` 已有 framing、struct/list 读写、遍历预算及相应测试；核心 wire-format 工作流、数据和输出高度重合。 | 直接重合风险，不选。 |

Terminfo 与 Cap’n Proto 分属不同问题域；它们只作为候选淘汰记录，不是 MoonLoudness 的运行依赖或实现基础。

## MoonLoudness 能力指纹与实现边界

- **问题域：** PCM 音频节目的客观响度、动态范围和峰值测量。
- **使用者：** 广播/播客质检；转码或媒体资产流水线；音频制作、游戏/直播监测；需要统一测量接口的音频库及测试工具。
- **输入与主工作流：** 固定采样率和布局配置 → 追加交错 PCM 分块 → 维护每声道滤波器和窗口能量状态 → 查询或结束测量并生成带错误语义的报告。
- **核心数据/算法：** 每声道 K-weighting biquad 状态、M/S 窗口能量、Integrated 门控块、LRA 的 short-term 响度分布、sample peak 与 true-peak FIR 状态。
- **预期输出：** Momentary、Short-term、Integrated LUFS/LKFS、LRA、sample peak 与 dBTP，以及无输入/短片段/配置不支持等明确状态。
- **复用接口：** 以稳定库 API 接收 PCM frame slice 并返回类型化快照；不绑定命令行、音频容器、播放器或特定业务系统。
- **排除能力：** 解码、容器读写、播放、转码、重采样、响度归一化、增益应用、limiter、编辑 UI、音频指纹/检索、频谱浏览和外部 FFmpeg 调用。

## 固定标准语义与保守支持范围

标准版本和信号链必须在代码、README、设计文档和后续申报材料中逐项声明；实现局部算法不等于符合整份标准。

1. 目标参考固定为 ITU-R BS.1770-5（2023）Annex 1/2 中适用于最多五个主声道的测量模型，并参考 EBU Tech 3341/3342/3343 的 EBU Mode 与 LRA 定义。BS.1770-5 对更大声道集合和对象音频另有 Annex 3/4；本项目不覆盖它们。
2. **采样率：首个可交付版本只接受 48,000 Hz。** 拒绝其他采样率，而不是复用 48 kHz 系数或默默重采样。若后续增加采样率，必须分别验证 K-weighting 系数响应、400 ms/100 ms 样本取整及 true-peak 过采样覆盖，再更新支持表。
3. **声道映射固定：** Mono → C；Stereo → L,R；5.0 → L,R,C,Ls,Rs，交错输入顺序与此一致。L/R/C 权重 1.0；Ls/Rs 权重 1.41（BS.1770 表值，约 +1.5 dB）。LFE 不计入标准响度，v0 API 不接受包含 LFE 的布局；不支持任意顺序、离散多声道、height/object/immersive layout 或用户自定义声道权重。
4. **窗口与门控：** M 窗口 400 ms；Integrated 使用完整 400 ms 块、75% 重叠（48 kHz 下 hop 为 100 ms），不足一个完整块的尾部块丢弃。S 窗口 3 s；LRA 从 short-term 窗口序列计算，窗口步长固定 100 ms（重叠 2.9 s，10 Hz）。Integrated 采用 −70 LUFS absolute gate 与低于 absolute-gated loudness 10 LU 的 relative gate；LRA 使用 −70 LUFS absolute gate、−20 LU 相对 gate 和第 10/95 百分位差。没有有效块或有效 LRA 样本时返回明确的 unavailable 状态，不制造数值。
5. **True peak：** 48 kHz 输入按 BS.1770-5 Annex 2 指定的 48 阶、4 相 FIR 插值器进行 4× oversampling 至 192 kHz，扫描重建相位的绝对峰值并换算 dBTP。使用浮点，因此不需要整数路径的 −12.04 dB 预衰减；滤波器系数按 ITU 文档列出的 4 相系数独立实现并做脉冲/相位测试。流式边界、历史样本及 finalize 尾部处理必须明确且 chunk 切分结果一致。sample peak 与 true peak 分开报告。
6. **合规措辞：** 即使上述目标项实现并通过自建测试，也只称“按列明边界实现 BS.1770-5/EBU Mode 相关测量”，不得据此宣称完整 BS.1770-5 或 EBU Tech 3341/3342 合规。没有运行 EBU 官方测试套件；EBU/ITU 官方测试素材的再分发授权未核实，因此不下载、不提交、不打包该素材。自建确定性向量只证明所覆盖的数学性质和实现边界，不替代官方符合性测试。

## 上游参考和相邻项目能力矩阵

上游算法语义参考：Rust crate [`sdroege/ebur128` 0.1.10](https://github.com/sdroege/ebur128)，固定参考 commit `0052abf06d8844f0972657c71e327d7eeee8967c`，MIT。它只用于理解公共行为/对照预期；MoonBit 实现独立编写，不复制 Rust 源码。上游版权声明及许可证仅在实际引用其代码时才涉及；当前约束是不复制代码。ITU/EBU 文档作为标准定义来源单独归属；标准文档中的测试素材不视为可自由再分发。

| 已检查相邻项目 | 检查到的能力/证据范围 | 与本项目的差别 | 判定及保留边界 |
|---|---|---|---|
| [MoonSpectrum](https://github.com/chgttyyr/MoonSpectrum) | 已记录版本 0.2.2；检查 README、源码、测试；侧重 FFT/频谱峰值和音频指标。 | 没有在已检查范围内看到 R128 的门控 Integrated、LRA、true-peak 分析报告闭环。 | 高度相邻；保留标准响度分析边界，不重复做频谱查看器。 |
| [hwlxmm/moonbit-dsp](https://github.com/hwlxmm/moonbit-dsp) | 已检查公开 API 与 frame analyzer/compressor 测试；包含帧 RMS/peak/主频/centroid 及 DSP 组件。 | 本项目测的是 R128/BS.1770 节目响度、历史门控和 LRA，不做通用 DSP 分析器或压缩器。 | 高度相邻；无需把它改造成响度测量才能使用。 |
| [dowdiness/moondsp](https://github.com/dowdiness/moondsp) | 已记录 0.6.0、固定 HEAD `5f76b3c54fe8976a86d16bfeb52be11d2053d703`；检查公开 DSP API、Biquad 与 oscillator tests；全仓源码审计未完成。 | 现有材料以合成、滤波、引擎为主；检查到的文件中未见本项目的 R128 报告 API。 | 高度相邻；不得把“不完整审计”写成证明其不存在功能。 |
| [mizchi/audio](https://mooncakes.io/docs/mizchi/audio) | 已检查包页面/包表面能力和测试线索：混音、buffer、解码/streaming/effects。 | 本项目不解码/混音/播放，处理调用方已解码的 PCM 并输出测量值。 | 相邻但功能不同；明确不做该项目已有的音频引擎/解码面。 |
| [MoonEcho](https://github.com/lin2077-zeming/MoonEcho) | 已记录 HEAD `68a173501546f8e37f94a10a9c4eabbbf3be9a55`；检查音频公开 API/测试：WAV adapter、downmix、resampling、fingerprint。 | 本项目不做容器、下混、重采样、指纹或匹配，只接收已映射 PCM。 | 相邻；限定为在线测量。 |
| [moon-certified](https://github.com/Juwan-Hwang/moon-certified) | 已检查 Cap’n Proto 候选实现/测试；音频子包被描述为 MFCC/WAV helper，但其源码审查仍有限。 | 未将有限检查当作不具备响度功能的证明；当前保留的区别是本项目固定 R128 门控/LRA/TP 能力。 | 未决的近邻；完成实施前如能访问其音频子包源码，再做定向核查。 |
| [mooncast](https://github.com/vectie/mooncast) | 已检查 render 路径编译 FFmpeg `loudnorm` 参数及 target LUFS/true-peak policy。 | 调用外部 FFmpeg，不在 MoonBit 进程内实现测量信号链。 | 相邻但不同；本项目是可嵌入库，不负责转码/调用 FFmpeg。 |
| [MoonPost](https://github.com/MaoDingA/moonbitpostqc) | 已记录的仓库检索返回 404。 | 无法检查 README/API/源码/测试，也不能据此判断功能。 | 检索限制；保留为待核查名称，不作为“无直接替代”的正面证据。 |
| MoonCakes/MoonBit 音频检索目录 | 永久注册表中保存的外部目录含 `bw448/moon-wav`、`dowdiness/moondsp`、`mizchi/audio`、`MoonSpectrum`、`MoonEcho`、`moon-certified`、`mooncast` 等；曾用 moon search/MoonCakes 文档页及 GitHub 项目检索与源码/测试检查。 | WAV 解码、DSP、合成、混音、采样流、指纹与 FFmpeg 驱动，与统一的标准响度报告环路相邻但非同一核心能力。 | 检索排名、页面可访问性、版本变化和部分源码审计范围构成限制；不能概括为全生态穷尽。 |

### 检查覆盖与限制

- 永久注册表：已复核当前 `project-registry.md` 中 MoonLoudness 指纹及上述音频 `external-checked` 记录；历史条目未在本任务中改写。
- MoonCakes：沿用前序候选审查记录的 `moon search`、相关 package docs/API/source/tests 范围；本次实现阶段不把 MoonCakes 搜索扩写成最新或穷尽性的全目录证明。
- MoonBit GitHub 项目：按上述已识别的音频邻接项目检查 README、公共 API、相关源码与测试；对 `moondsp`、`moon-certified`、`moonpost` 保留文中注明的审计限制。
- OSC 比赛助手：本机已安装并按其查重指南执行；使用其本地/仓库材料，不重开线上比赛章程页面修改比赛规则。
- 反向语义查重覆盖：`EBU R128`、`BS.1770`、loudness meter、integrated gating、momentary/short-term、LRA、true peak、PCM analyzer、`loudnorm` 等能力词；结论只限于上面记录的包、仓库、API、源码和测试范围。
- 复核日期：2026-10-13；重大边界变化、上游新版本或发现新的 MoonBit 响度实现时应重新核查。

## 决策

选择 MoonLoudness。理由是它处理与邻近 MoonBit 音频库不同的核心对象和问题循环：以固定布局 PCM 流的时间窗口能量为状态，执行 K 加权、广播响度门控和 short-term 分布统计，并输出可直接供多个下游系统复用的标准化测量报告。项目不会以解码、播放、频谱 UI、FFmpeg 参数转发形成差异，也不宣称尚未测试的标准合规性。开始实现前必须坚持上述 48 kHz、Mono/Stereo/5.0 布局与 TP 算法边界；如代码实际只完成其中子集，文档须同步缩窄已交付声明。

## 2026-10-14 接手复核（定向解决未决邻接项）

使用已安装 osc2026-guide 的 Project Research Guide，保留固定比赛规则。重新执行 moon search：loudness、r128、bs1770、true peak、loudnorm（limit 100）；audio 返回上限 100 项，不能视作全目录穷尽。公开 MoonCakes moon view --json 核对 Juwan-Hwang/moon-certified 0.1.1、dowdiness/moondsp 0.6.0、MaoDingA/moonpost 0.2.1 的版本、许可证及仓库。公开网页搜索无可用结果，不作为无替代的证据。GitHub API recursive tree 均未截断，并通过公开 codeload 下载固定 SHA 的源码副本（只用于本地审查，不分发其源码）。

| 邻接项目 | 固定 SHA / 实际审查范围 | 核心流程与判断 |
|---|---|---|
| moon-certified | 94dd850ce24db5610e720035d5bdb1ecb2923e43；README、audio_processing/features 和 wav 源码/测试；575 个 mbt/mbti/md 文件定向能力检索 | 线性重采样、framing、mel、MFCC、WAV；非 K 加权门控响度报告。以前音频源码未决限制在此范围内解决。 |
| moondsp | 8eb0dc26fb8cc69d2199526413d001541fed2724；README、dsp 接口、filter/gain/osc 源码及测试；486 个 mbt/mbti/md 文件定向能力检索 | AudioBuffer、Biquad、Adsr、DelayLine 和合成引擎；未在审查范围内发现 R128 集成门控/LRA 闭环。独立计量库可直接接收这些引擎的 PCM，不复制其合成/效果器。 |
| MaoDingA/moonpost | 6f7b615f9d94e35071dbd3af8573e9a2cc9c447e；README.en.md、qc/timecode 接口、checks/qc 源码/测试，全库能力检索 | SRT/WebVTT/ASS、字幕阅读/时间码 QC，不接收 PCM 计算响度。纠正旧报告误用 vectie/moonpost URL；旧 404 不作为证据。 |

反向检索 loudness、LUFS、BS.1770、R128、loudnorm、true peak、integrated gating、K-weighting；关键词检索只辅助定位，不替代流程/API/测试审查。永久注册表 reserved/completed 均视作保留；MoonPhone 的号码计划和 MoonCite 的 CSL 渲染流程不重合。保留 Terminfo 与 Cap'n Proto 直接重复的淘汰结果。

接手结论：**在已记录检索范围内未发现成熟直接替代**。保留 MoonLoudness，不换题。不声称覆盖所有私有、未索引、未发布或未来版本；源码检查为定向审查，而非对每行程序形式化证明。

## 2026-10-20 验收阶段语义复查补充

保留此前三领域候选、淘汰原因与历史记录，不按名称是否重复作结论。本轮执行 11 个 `moon search` 查询（每项 limit 100），并检索 GitHub MoonBit 仓库、MoonCakes 精确版本与永久注册表；定向阅读近邻 README、API、源码和测试。受限或返回 403 的请求记为不可访问，不记作零结果。检索范围仍不能涵盖私有、未索引及未来版本。

- **MoonVoice**：仓库 [`yabaobao070510/moonvoice`](https://github.com/yabaobao070510/moonvoice)，审阅树 `f0ecc993d0775612b4cfb8e8e329d242c246b213`，其清单声明 `yabaobao/moonvoice@0.1.0`。确实提供离线 K 加权、综合响度、LRA、采样峰值和 pyloudnorm 金标测试，不应概括为只有 MFCC。与本库测量数学高度相邻；其核心是全长 Audio/加权 PCM/离线块的语音分析前端。本库核心是有界分块输入、窗口预热与结束/不可用状态协议、流式 FIR 真峰值、可脱离所有权的有限历史，以及独立节目的分布聚合。长期媒体流无需保留整段 PCM，且可嵌入不需要语音特征的系统，构成独立库的必要性，而不只是在相邻项目上增添一个输出字段。未以包清单 404 推断成熟度。
- **MoonCast**：FFmpeg `loudnorm` 两遍测量、导出和复测已经实现，是高度相邻的真实媒体流水线。它依赖外部解码/处理链；本库只接收已解码 PCM，以进程内测量 API 服务流水线、实时仪表和编辑器，不替代 MoonCast 的媒体处理工作流。
- **mizchi/audio**：精确安装并审阅 `0.1.1` 包，源码仓库为 [`mizchi/audio-mpt`](https://github.com/mizchi/audio-mpt)。它实现游戏音频 mixer/voice/codecs/streaming/effects；不是完整的本库响度门控和独立节目分布聚合协议。旧错误仓库 URL 的 404 不作为不存在依据。
- 延续检查 MoonSpectrum、hwlxmm/dsp、moondsp、MoonEcho、moon-certified、MoonPost 的实际能力，未将其中频谱、DSP 基元、音效或质检流程误作不存在。永久注册表全部 reserved/completed 项目继续保留，包括 MoonCite、MoonPhone；本轮不重新登记本项目指纹或改换选题。

结论：**在已记录检索范围内未发现成熟直接替代**。保留现有项目与历史；MoonVoice、MoonCast 属高度相邻项目，后续版本仍需持续关注。详细检索证据与本地验收记录保存在仓库外，未上传私人申报书。
