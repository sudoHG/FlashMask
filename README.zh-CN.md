# Flash Mask

[![Release](https://img.shields.io/github/v/release/sudoHG/FlashMask?style=flat-square&label=release)](https://github.com/sudoHG/FlashMask/releases/latest) [![Stars](https://img.shields.io/github/stars/sudoHG/FlashMask?style=flat-square&label=stars)](https://github.com/sudoHG/FlashMask/stargazers) [![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat-square)](LICENSE) [![macOS](https://img.shields.io/badge/macOS-26%2B-black?style=flat-square)](https://apps.apple.com/app/id6803817818) [![Apple Silicon](https://img.shields.io/badge/Apple_Silicon-arm64-black?style=flat-square)](https://apps.apple.com/app/id6803817818) [![README views](https://hits.sh/github.com/sudoHG/FlashMask.svg?style=flat-square&label=README%20views)](https://hits.sh/github.com/sudoHG/FlashMask/)

简体中文 | [English](README.md)

**快速制作图片蒙版，让 AI 看懂你要改的是哪里。**

> “不是这里，是旁边那个”——这句话你重复过几遍？  
> 想改一个细节，AI 却把整张图都改了。以前只能去大型图像软件里处理这种繁琐的选区和导出。  
> 现在 Flash Mask 帮你把这套操作压缩到几秒之内：拖入图片、圈出要改的区域、一键复制结构化 JSON 坐标发给 AI，它就能准确识别修改位置。需要像素级精细处理时，直接导出 1:1 黑白蒙版。

![Flash Mask Mac App 真实工作界面：圈选图片区域并复制 JSON 坐标给 AI](assets/app-screenshot.png)

---

## 产品概述

Flash Mask 是一款专为 AI 图像编辑与视觉工作流打造的轻量 macOS 原生辅助工具。在与 AI 模型或 Coding Agent 协作修图时，纯文字描述往往难以准确界定修改范围，容易导致整图失真或改错位置。

Flash Mask 省去了在大型图像软件中繁琐套索、填充和导出图层的步骤，在几秒内将你的圈选转化为 Agent 可直接解析的坐标数据：

- **默认输出结构化 JSON 坐标**：一键生成包含像素坐标、归一化坐标、原图尺寸、本地文件绝对路径以及可选修改意图（Prompt）的标准 JSON 数据，直接粘贴到 AI 对话框或 Agent 工作流中使用。
- **按需导出 1:1 黑白蒙版 PNG**：面向需要像素级 Mask 的 Inpainting（局部重绘）模型与传统工作流，一键导出与原图尺寸严格一致的黑白 PNG 蒙版（选区纯白、背景纯黑、边缘无羽化）。
- **100% 本地离线与数据私密**：所有图片解析、坐标计算与蒙版生成全部在你的 Mac 本地完成。不上传任何图片、文件路径、坐标数据或 Prompt。无需注册登录，无广告，无分析 SDK。
- **专注于位置界定，无内置 AI 绑定**：Flash Mask 负责精准表达“要改哪里”与“改什么”，实际的图像生成与修改由你正在使用的 AI 工具或 Agent 完成，不强行绑定特定 AI 服务或云端模型。

## 典型使用场景

- **角色设定与生成图局部微调**：圈出需要修正的手部、面部五官、服饰或配件细节，让 AI 在保持整体画面稳定的前提下进行针对性重绘。
- **照片背景消除与杂物清理**：快速框选背景中的路人、杂乱物体、水印或瑕疵，供修图 Agent 进行智能消除与背景补全。
- **海报与设计素材局部修改**：精准标记海报、电商素材、宣传图中需要替换的文字排版、产品主体或局部装饰元素。
- **Coding Agent UI 截图标注**：为自动化编程 Agent 标明 UI 截图中的问题位置，例如 iOS Simulator、macOS 原生 App、Canvas、WebGL、地图、图表或游戏 UI 中的文字截断、控件重叠与布局错位，将位置坐标与修改要求一并交付给 Agent。

## 快速上手流程

1. **拖入图片**：将 PNG、JPEG/JPG 或 WebP 图片拖入窗口，或点击 **打开图片**。支持平移缩放、**适应窗口** 与 **实际尺寸（1:1）** 视图。
2. **圈选与微调区域**：
   - 在图片上按住鼠标圈出不规则区域，松开即可完成添加；支持圈选多个独立区域（自动合并为并集）。
   - 点击已有区域可进行微调：支持整体拖拽移动选区，或自由拖动、新增、删除多边形节点。
   - 可选：在 **“想让 Agent 做什么？”** 输入框中填写本次修改要求（例如：`"保留山体，去掉天空中的云层。"`）。
3. **一键复制 JSON 或导出蒙版**：
   - 点击 **复制 JSON**：将包含图片路径、尺寸、区域多边形坐标及修改要求的结构化数据复制到剪贴板，直接粘贴给 AI / Agent。
   - 点击 **导出黑白蒙版 PNG**：通过系统保存面板导出与原图等宽等高的黑白 PNG 蒙版文件。

## JSON 坐标数据格式

Flash Mask 输出带版本标识、自解释的标准 JSON 数据，内置像素坐标与 `[0.0, 1.0]` 归一化坐标双体系（左上角原点，向右为 X、向下为 Y）：

```json
{
  "mask_spec_version": "1.0",
  "instruction": "This JSON identifies areas the user selected in the source image. Each polygon marks one selected area; multiple polygons form a combined selection; the first and last points are connected automatically. Interpret the selected areas and any `prompt` in the context of the current conversation. If `prompt` is present, it expresses the user's intent regarding the image.",
  "source_image": {
    "file_name": "example.jpg",
    "width": 1920,
    "height": 1080,
    "file_path": "/Users/username/Pictures/example.jpg"
  },
  "coordinate_system": {
    "origin": "top-left",
    "x_direction": "right",
    "y_direction": "down"
  },
  "prompt": "保留山体，去掉天空中的云层。",
  "regions": [
    {
      "id": 1,
      "shape": "polygon",
      "points_px": [[96, 108], [480, 108], [480, 432], [96, 432]],
      "points_normalized": [[0.05, 0.1], [0.25, 0.1], [0.25, 0.4], [0.05, 0.4]]
    }
  ]
}
```

### 字段说明

- `mask_spec_version`：协议版本号（当前为 `"1.0"`）。
- `instruction`：内置自解释说明，引导下游 AI 模型或 Agent 理解圈选多边形与修改意图。
- `source_image`：原图文件名、像素宽高以及 Mac 本地完整绝对路径（`file_path` 为 Mac 端专属，方便本地 Agent 直接读取原图）。
- `coordinate_system`：坐标系规范（固定为左上角原点，向右为 X、向下为 Y）。
- `prompt`：可选。用户填写的任务级修改说明。
- `regions`：圈选区域列表。每个区域包含整数像素坐标 `points_px`（`[x, y]`）与无量纲归一化坐标 `points_normalized`（`[x/width, y/height]`）。首尾节点自动闭合，多区域共同构成并集。

## 核心功能特性

- **格式支持**：支持 PNG、JPEG/JPG、WebP 格式图片导入。
- **多区域圈选**：支持在单张图片上圈选多个不规则区域，导出时自动计算并集合并。
- **交互式节点编辑**：选区支持整体拖拽平移，可精准新增、拖动或删除多边形顶点。
- **画布自由导航**：平滑缩放与拖拽平移，提供 **适应窗口** 与 **实际尺寸（1:1 像素）** 快捷视图。
- **任务级修改说明**：支持为当前图片标注附加 Prompt 意图说明。
- **双坐标系输出**：兼具绝对像素坐标与分辨率无关的归一化坐标，适配不同 Agent 与模型接口。
- **原图尺寸保真**：导出的黑白 PNG 蒙版严格与原图宽高 1:1 对应，选区纯白、背景纯黑、无羽化。
- **本地路径直达**：Mac 端复制的 JSON 包含验证后的本地文件绝对路径，方便本地自动化脚本与 Agent 直接定位文件。
- **中英双语界面**：提供完整中文与英文界面，一键无缝切换。
- **隐私与离线优先**：纯本地运行，无需账号登录，无任何广告或分析追踪 SDK。

## 获取 Flash Mask

- **Mac App Store**：在 [Mac App Store](https://apps.apple.com/app/flash-mask/id6803817818?mt=12) 获取官方预编译版本。一次性买断，终身可用，无任何订阅或应用内购买。
- **官方网站**：访问 [flashmask.net](https://flashmask.net/) 了解产品动态与体验说明。
- **源码 Release**：在 [GitHub Releases](https://github.com/sudoHG/FlashMask/releases/tag/v1.0.0) 获取源码归档。（注：官方二进制安装包统一通过 Mac App Store 分发，GitHub Releases 不附加预编译安装包）。

## 本仓库开源范围

本仓库开源了 Flash Mask Mac 客户端的完整源代码，包含：
- macOS AppKit / WKWebView 原生宿主外壳与 Xcode 工程（`macos/`）
- 内嵌的 HTML / JavaScript 编辑器核心（`index.html`）
- 坐标合同协议、套索选区清洗与蒙版生成逻辑（`src/`）
- Flash Mask 1.0 JSON 坐标数据校验规范（`schemas/`）
- 核心自动化契约与单元测试套件（`tests/`）

*注：本仓库包含独立的 Mac 应用及编辑核心，不包含独立网页版部署脚本或运营后端服务（如营销展示页、额度与广告服务、数据统计及运营设施）。根据 Apache-2.0 许可证，核心编辑模块与共享数据契约可自由移植和改造。*

## 从源码构建 Mac App

### 环境要求

- Apple Silicon Mac（`arm64` 芯片架构），运行 **macOS 26** 或更高版本
- 安装完整 **Xcode**，包含 **macOS 26 SDK**
- 纯 Swift、AppKit 与 WebKit 构建，无外部 Swift 依赖包（Zero external Swift dependencies）

### 构建命令

在仓库根目录下执行：

```sh
xcodebuild \
  -project 'macos/Flash Mask.xcodeproj' \
  -scheme 'Flash Mask' \
  -configuration Release \
  -derivedDataPath '.derivedData/local' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

**构建产物路径**：`.derivedData/local/Build/Products/Release/Flash Mask.app`

该命令执行无签名本地构建，编译原生包装外壳并将 `index.html` 及应用资源打包成独立 App。此构建命令已在 macOS 26.6.2 / Xcode 26.6 环境下实测验证。

> **签名与分发说明**：若需在 Xcode 中直接调试运行或生成已签名的二进制产物，请在 Xcode 的 *Signing & Capabilities* 中选择您自己的 Apple 开发者证书（Development Team）。若您分发基于本源码的衍生版本，请使用您自己的 Bundle ID、应用名称和品牌资产，并自行负责代码签名与平台审核。

## 运行核心测试

运行核心协议与逻辑测试需要 **Node.js 22** 或更高版本。（*Node.js 仅用于运行核心契约与算法测试，编译 Mac App 本身不依赖 Node.js*）。

```sh
npm ci --ignore-scripts
npm test
```

测试套件涵盖：
- Mac 端与 Web 端 JSON Coordinate Contract 的 Schema 校验
- 平台特定字段约束与省略规则
- 多边形几何计算与套索选区顶点清洗（平滑与去冗余）
- 1:1 黑白 PNG 蒙版栅格化像素渲染准确性
- 性能边界与顶点数量限制保护

## 目录结构

| 路径 | 说明 |
|---|---|
| `index.html` | Mac App 内嵌编辑界面、画布交互控制与 UI 状态机 |
| `src/` | 坐标合同协议解析、蒙版栅格化与套索选区清洗算法 |
| `schemas/` | Flash Mask 1.0 坐标数据合同的官方 JSON Schema 定义 |
| `macos/` | AppKit / WKWebView 原生宿主包装、安全作用域文件访问与 Xcode 工程 |
| `tests/` | 核心单元测试、契约测试与验证用例 |

## 开源许可证与声明

Flash Mask 原创源代码采用 [Apache License 2.0](LICENSE) 开源许可证。在遵守许可证条款的前提下，您可以自由使用、修改、分发本代码，或用于商业与闭源衍生产品。

- 项目版权与归属声明请参见 [NOTICE](NOTICE)。
- 第三方组件与依赖许可证请参见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
- 产品名称“Flash Mask”、Logo 及应用图标等品牌视觉资产受独立 [品牌资产条款](BRAND_ASSETS.md) 保护，不纳入 Apache-2.0 授权范围。
- **用户数据归属**：使用 Flash Mask 生成的 JSON 坐标数据、图片和 PNG 蒙版完全归用户所有，不受 Apache-2.0 许可证约束。
