# Flash Mask

[![Release](https://img.shields.io/github/v/release/sudoHG/FlashMask?style=flat-square&label=release)](https://github.com/sudoHG/FlashMask/releases/latest) [![Stars](https://img.shields.io/github/stars/sudoHG/FlashMask?style=flat-square&label=stars)](https://github.com/sudoHG/FlashMask/stargazers) [![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat-square)](LICENSE) [![macOS](https://img.shields.io/badge/macOS-13%2B-black?style=flat-square)](https://apps.apple.com/tw/app/flash-mask/id6803817818?mt=12) [![Universal](https://img.shields.io/badge/Universal-arm64%20%2B%20x86__64-black?style=flat-square)](https://apps.apple.com/tw/app/flash-mask/id6803817818?mt=12) [![README views](https://hits.sh/github.com/sudoHG/FlashMask.svg?style=flat-square&label=README%20views)](https://hits.sh/github.com/sudoHG/FlashMask/)

[English](README.md) | [简体中文](README.zh-CN.md) | 繁體中文 | [日本語](README.ja.md) | [Deutsch](README.de.md) | [Français](README.fr.md) | [Español](README.es.md)

**快速建立圖片遮罩，精確指引 AI 編輯區域。**

<a href="https://apps.apple.com/tw/app/flash-mask/id6803817818?mt=12"><img src="https://tools.applemediaservices.com/api/badges/download-on-the-mac-app-store/black/zh-tw?size=250x83" alt="在 Mac App Store 下載" height="54"></a>

> 「不是那裡——是旁邊那個。」你對著 AI 說過多少次這句話？  
> 只想微調一個小細節，模型卻把整張圖重新生成。以往要解決這個問題，得開啟笨重的修圖軟體，進行繁瑣的選取與匯出。  
> Flash Mask 將整個過程縮短至幾秒鐘：放入圖片、圈出你想修改的區域，直接複製結構化的 JSON 座標給你的 AI 或 Agent，讓它精確掌握編輯位置。需要像素級精度時，也能一鍵匯出 1:1 黑白遮罩。

![macOS 上的 Flash Mask：圈選圖片區域並複製 JSON 座標給 AI Agent](assets/app-screenshot.png)

---

## 總覽

Flash Mask 是一款專為 AI 圖片編輯與視覺工作流程打造的輕量原生 macOS 輔助應用程式。在與 AI 模型或 Coding Agent 協作時，單靠文字提示詞往往難以精確指定邊界，容易導致整張圖片被意外修改，或是在錯誤的位置進行編輯。

在 macOS 上，Flash Mask 輸出包含整張圖片指示與個別區域備註的 JSON 1.1。官方網站的 Web 版則維持使用 JSON 1.0。

### Mac App

- 直接從剪貼簿貼上螢幕截圖。
- 為整張圖片新增一條指示，並為個別區域新增自訂備註。
- 提供 7 種介面語言：英文、簡體中文、繁體中文、日文、德文、法文及西班牙文。
- 使用專屬設定視窗切換語言、檢查更新，以及開啟官方網站、說明文件、GitHub 原始碼或支援頁面。

無需在複雜的修圖軟體中與套索工具、填色圖層和手動匯出費力周旋，Flash Mask 能在數秒內將你的選取範圍轉換為可直接供 Agent 使用的座標：

- **預設輸出結構化 JSON 座標**：一鍵複製標準化 JSON，內含像素座標、正規化座標、原始圖片尺寸、本機絕對檔案路徑，以及選填的編輯指示（prompt）。可直接貼入 AI 對話或 Agent 工作流程中。
- **隨需匯出 1:1 黑白 PNG 遮罩**：針對需要像素級遮罩的 Inpainting（局部重繪）模型與傳統處理流程，可匯出符合原圖尺寸的清晰 PNG 遮罩（純白選取區域、純黑背景、無羽化與反鋸齒邊緣）。
- **100% 本機離線運作，保障隱私**：圖片解碼、座標計算與遮罩渲染完全在你的 Mac 上執行。絕不會上傳任何圖片、檔案路徑、座標或提示詞。無需帳號、無需登入、無廣告，亦無任何追蹤 SDK。
- **專注於空間定位——無內建 AI 綁定**：Flash Mask 專注於清楚傳達 *要改哪裡* 以及 *要改什麼*。實際的圖片生成與編輯工作則由你偏好的 AI 工具或 Agent 負責——沒有廠商鎖定，也無雲端依賴。

## 應用場景

- **角色繪圖與 AI 生成修圖**：圈出雙手、五官特徵、服飾或配件，引導精準的局部重繪，同時保持圖片其餘部分不變。
- **照片清理與物件移除**：快速框選背景路人、雜物、浮水印或瑕疵，讓圖片編輯 Agent 能乾淨地移除並進行修復填補。
- **海報與行銷素材編輯**：標記海報、橫幅廣告與電商素材中需要替換的特定文字排版、產品主體或圖形元素。
- **Coding Agent 的 UI 缺陷標註**：精準指出 UI 螢幕截圖中的視覺問題——例如 iOS 模擬器、macOS 應用程式、Canvas、WebGL、地圖、圖表或遊戲 UI 中的文字截斷、控制項重疊或排版跑版——並將精確座標與修復指示直接交給你的 Coding Agent。

## 快速開始

1. **開啟圖片**：將 PNG、JPEG/JPG 或 WebP 圖片拖放至視窗中、點擊 **開啟圖片**，或是從剪貼簿貼上螢幕截圖。可平移、縮放，並在 **符合視窗** 與 **實際大小**（1:1 像素）視圖之間切換。
2. **圈選與微調區域**：
   - 在圖片上點擊並拖曳以手繪圈選區域；放開滑鼠按鈕即可新增。可視需要繪製多個獨立區域（會自動合併為聯集）。
   - 點擊任何已建立的區域進行微調：拖曳整個選取範圍來重新定位，或是拖曳、新增及刪除多邊形頂點。
   - 選填：在 「**想讓 Agent 做什麼？**」 欄位中輸入整張圖片的指示，接著選取特定區域為該區域新增備註。
3. **複製 JSON 或匯出遮罩**：
   - 點擊 **複製 JSON**：將結構化資料——包含本機檔案路徑、圖片尺寸、多邊形座標與編輯提示詞——複製到剪貼簿，以便直接貼入 AI 或 Agent。
   - 點擊 **匯出遮罩 PNG**：開啟 macOS 儲存面板，匯出符合原圖尺寸的清晰黑白 PNG 遮罩。遮罩會標記選取區域；個別備註則包含於 JSON 中。

## JSON 座標資料格式

Flash Mask 輸出具備版本控制且自帶說明的 JSON，並提供雙重座標系統——絕對像素座標與正規化 `[0.0, 1.0]` 座標（原點位於左上角，X 軸向右遞增，Y 軸向下遞增）。Mac App 使用 JSON 1.1；官方網站的 Web 版則使用 JSON 1.0：

```json
{
  "mask_spec_version": "1.1",
  "instruction": "This JSON identifies areas the user selected in the source image. Each polygon marks one selected area; multiple polygons form a combined selection; the first and last points are connected automatically. The top-level `prompt`, if present, applies to the whole image. Each region's `prompt`, if present, applies only to that region. Interpret these texts in the context of the current conversation. The combined geometry marks range only; it does not assign a processing order among regions.",
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
  "prompt": "Keep the building",
  "regions": [
    {
      "id": 1,
      "shape": "polygon",
      "points_px": [[96, 108], [480, 108], [480, 432], [96, 432]],
      "points_normalized": [[0.05, 0.1], [0.25, 0.1], [0.25, 0.4], [0.05, 0.4]],
      "prompt": "Remove stray lines"
    },
    {
      "id": 3,
      "shape": "polygon",
      "points_px": [[600, 108], [900, 108], [900, 432], [600, 432]],
      "points_normalized": [[0.3125, 0.1], [0.46875, 0.1], [0.46875, 0.4], [0.3125, 0.4]],
      "prompt": "Use a light gray background"
    }
  ]
}
```

### 欄位說明

- `mask_spec_version`：規格版本。Mac App 目前輸出 `"1.1"`；官方網站 Web 版維持使用 `"1.0"`。
- `instruction`：內嵌的自我說明指引，用於指示下游 AI 模型或 Agent 如何解讀多邊形及使用者意圖。
- `source_image`：來源檔案名稱、像素尺寸（`width`、`height`）以及本機 Mac 絕對檔案路徑（`file_path` 為 macOS App 專有，以便本機 Agent 直接存取檔案）。
- `coordinate_system`：座標系統定義（固定為左上角原點，X 軸向右遞增，Y 軸向下遞增）。
- `prompt`：選填。在 Mac JSON 1.1 中，此指示適用於整張圖片。
- `regions`：標記區域清單。每個區域包含整數像素座標（`points_px` 格式為 `[x, y]`）與無因次正規化座標（`points_normalized` 格式為 `[x/width, y/height]`）。Mac JSON 1.1 可包含特定區域的選填 `prompt`；當刪除其他區域時，區域 ID 仍維持穩定。起點與終點頂點會自動閉合，多個區域則組合成合併聯集。

嚴格遵循 JSON 1.0 的解析程式在接收 JSON 1.1 前必須升級其驗證器。Flash Mask 不會無預警丟棄區域備註。

## 功能特色

- **廣泛的格式支援**：支援匯入 PNG、JPEG/JPG 與 WebP 圖片。
- **多區域選取**：可在單張圖片上繪製多個不規則選取區域；匯出時選取區域會自動合併為單一遮罩。
- **互動式頂點編輯**：可拖曳整個選取區域以重新定位，或精確新增、移動與刪除多邊形頂點。
- **順暢的畫布瀏覽**：順暢平移與縮放，並提供 **符合視窗** 與 **實際大小**（1:1 像素）視圖的快速切換。
- **圖片與區域備註**：在 Mac App 中可為整張圖片附加選填指示，並為個別區域新增備註。
- **雙重座標系統**：同時產生絕對像素座標與不受解析度影響的正規化座標，以支援各種 Agent 與模型的結構定義。
- **忠實呈現原始解析度**：黑白 PNG 遮罩 1:1 符合來源圖片尺寸，以純白選取區域、純黑背景以及清晰無羽化的邊緣進行渲染。
- **直接提供本機檔案路徑**：macOS App 會在 JSON 中輸出經過驗證的絕對檔案路徑，讓本機自動化腳本與 Agent 能立即定位檔案。
- **7 種介面語言**：英文、簡體中文、繁體中文、日文、德文、法文及西班牙文。App 預設遵循系統語言；可隨時從視窗頂部的語言選單或「設定」中切換，不會遺失目前的圖片、選取區域或備註。
- **隱私與離線優先**：100% 本機執行，無需登入、零廣告，且不含任何追蹤或分析 SDK。

## 取得 Flash Mask

- **Mac App Store**：在 [Mac App Store](https://apps.apple.com/tw/app/flash-mask/id6803817818?mt=12) 取得官方預先建置的應用程式。一次性購買即可終身使用——無訂閱制，亦無 App 內購買項目。
- **官方網站**：造訪 [flashmask.net](https://flashmask.net/) 了解產品更新與詳細資訊。
- **原始碼發行版**：從 [GitHub Releases](https://github.com/sudoHG/FlashMask/releases) 下載原始碼封存檔。*（備註：官方二進位組建僅透過 Mac App Store 發行；GitHub Releases 不提供預先編譯的二進位檔）*。

## 開源範圍

本儲存庫提供 Flash Mask macOS 用戶端的完整開放原始碼，包括：
- 原生 macOS AppKit / WKWebView 主機包裝層與 Xcode 專案（`macos/`）
- 內嵌式 HTML / JavaScript 編輯器核心（`index.html`）
- 座標協定解析、選取頂點清理與遮罩生成邏輯（`src/`）
- Flash Mask 1.0 與 1.1 JSON 座標協定驗證結構定義（`schemas/`）
- 核心自動化協定與單元測試套件（`tests/`）

*備註：本儲存庫包含獨立的 macOS 應用程式及其編輯核心。不包含獨立的 Web 部署腳本或商業後端服務（例如行銷宣傳頁面、額度/廣告系統、數據分析或代管基礎設施）。在 Apache-2.0 授權條款下，核心編輯模組與共用資料協定均可自由移植與改編。*

## 參與貢獻

請參閱[貢獻指南](贡献指南.md)了解本機檢查、CI 涵蓋範圍與 Pull Request 的詳細資訊。

## 從原始碼建置 Mac App

### 必要條件

- 一台完整安裝 **Xcode** 的 Mac；主機的 macOS 版本必須受該 Xcode 版本支援
- 本應用程式目標為 **macOS 13.0 或更新版本**，並建置為通用二進位檔（`arm64` + `x86_64`）
- 純 Swift、AppKit 與 WebKit 建置——完全零外部 Swift 套件依賴

### 建置指令

在儲存庫根目錄執行以下指令：

```sh
xcodebuild \
  -project 'macos/Flash Mask.xcodeproj' \
  -scheme 'Flash Mask' \
  -configuration Release \
  -derivedDataPath '.derivedData/local' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

**建置輸出位置**：`.derivedData/local/Build/Products/Release/Flash Mask.app`

此指令會建立未簽署的本機組建，編譯原生包裝層並將 `index.html` 與應用程式資源打包成獨立的 App。Release 設定以 macOS 13.0 為目標，並同時建置 `arm64` 與 `x86_64` 架構切片。官方 App Store 版本則是透過獨立的 Xcode Archive 與發行流程產生，而非此本機建置指令。

### 一鍵建置腳本

或者，可以使用隨附的 `build.sh` 腳本（執行 `./build.sh --help` 查看詳細資訊）：

```sh
./build.sh
./build.sh --version 1.3.1 --build-number 9 --dmg
```

此腳本預設版本為 `1.3`、組建編號為 `8`；`--version` 與 `--build-number` 可覆寫這些數值。它會檢查建置完成的 App 版本、最低 macOS 版本需求以及兩種架構切片。`--dmg` 會將該未簽署的 App 打包以供本機測試；產生的 DMG 不適用於通過 Gatekeeper 的發行管道。

若要在 Mac App Store 以外的管道發行，請使用你自己的 **Developer ID Application** 憑證與安全時間戳記為 App 進行程式碼簽署、驗證其簽署、提交公證，並附加與驗證通過的票證。接著使用以下指令打包該 App：

```sh
./build.sh --package-app "/path/to/stapled/Flash Mask.app"
```

`--package-app` 會驗證 Developer ID 簽署、安全時間戳記、公證票證、macOS 13.0 最低需求與兩種架構切片，接著建立具備版本號的 DMG，無需再次執行 `xcodebuild` 或重新簽署。DMG 本身仍為未簽署狀態；對外部容器進行簽署、公證與附加票證是獨立發行時的額外步驟。此輔助腳本不會進行簽署、公證、Archive 或產出官方 App Store 組建。衍生版本必須使用自訂的 Bundle ID、應用程式名稱與品牌素材。

## 執行核心測試

執行核心協定與邏輯測試套件需要 **Node.js 22** 或更新版本。*（Node.js 僅用於測試協定與演算法；建置 macOS App 本身不需要 Node.js）*。

```sh
npm ci --ignore-scripts
npm test
```

測試套件涵蓋：
- 針對 macOS 與 Web 目標的 JSON 座標協定結構定義驗證
- 平台專屬的欄位限制與省略規則
- 多邊形幾何計算與套索頂點簡化（平滑化與冗餘頂點消除）
- 1:1 黑白 PNG 遮罩像素點陣化精準度
- 效能邊界與頂點數量上限防護機制
- 在地化資源：所有 7 種語言之間相同的鍵、佔位符與配對的 bundle 資源

在 macOS 上，`npm test` 也會編譯並執行原生 Swift 測試（在地化資源與「設定」視窗位置），過程中會短暫開啟測試視窗。如需單獨執行原生介面測試，請使用 `node --test tests/mac-localization-ui.js`。CI 會在 Linux 上執行核心測試，並在 Apple Silicon macOS 15、Intel 及 macOS 14 上執行原生與介面測試；詳情請參閱[貢獻指南](贡献指南.md)。

## 目錄結構

| 路徑 | 說明 |
|---|---|
| `index.html` | 內嵌編輯器介面、畫布互動與 UI 狀態機 |
| `src/` | 座標協定解析、遮罩點陣化與選取頂點清理演算法 |
| `src/localizations/` | 7 種語言的介面文字，每種語言各一個 JSON 檔案 |
| `scripts/` | 建置時期用於驗證並封裝配對在地化資源的腳本 |
| `schemas/` | Flash Mask 1.0 與 1.1 座標協定的官方 JSON Schema 定義 |
| `macos/` | 原生 AppKit / WKWebView 主機包裝層、安全性範圍檔案存取與 Xcode 專案 |
| `tests/` | 單元測試、協定驗證套件與測試固件（test fixtures） |

## 授權與聲明

Flash Mask 原始程式碼採用 [Apache License 2.0](LICENSE) 授權。在遵循授權條款的前提下，你可以自由使用、修改與散布本軟體，包括用於商業與專有的衍生作品中。

- 著作權與署名聲明記載於 [NOTICE](NOTICE)。
- 第三方元件與相依套件列於 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
- 品牌資產——包括「Flash Mask」名稱、標誌與應用程式圖示——受獨立的[品牌資產條款](BRAND_ASSETS.md)保護，不屬於 Apache-2.0 授權範圍。
- **使用者資料所有權**：所有使用 Flash Mask 產生的 JSON 座標資料、圖片與 PNG 遮罩均完全屬於使用者所有，不受 Apache-2.0 授權規範。
