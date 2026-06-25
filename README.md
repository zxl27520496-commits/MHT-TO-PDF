# MHT 转 PDF 安卓应用

基于 Flutter + Android WebView 的 MHT/MHTML 转 PDF 工具，支持批量转换。

> 📱 **只有手机？没有电脑也能打包！** 查看 [手机打包教程](手机打包教程.md)，用 GitHub Actions 在线构建 APK。

## 功能特点

- 图形化界面，操作简单
- 支持批量添加多个 MHT/MHTML 文件
- 批量转换，实时显示进度
- 可自定义输出目录
- 转换完成后可直接打开 PDF
- A4 纸张，高质量渲染

## 项目结构

```
mht_to_pdf_app/
├── lib/
│   ├── main.dart                         # 应用入口
│   ├── pages/
│   │   └── home_page.dart                # 主页面UI
│   ├── models/
│   │   └── conversion_item.dart          # 数据模型
│   └── services/
│       └── mht_converter_service.dart    # 转换服务（MethodChannel）
├── android/
│   ├── app/
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       ├── kotlin/com/example/mht_to_pdf/
│   │       │   └── MainActivity.kt       # 原生转换逻辑
│   │       └── res/
│   ├── build.gradle
│   └── settings.gradle
└── pubspec.yaml
```

## 环境要求

- Flutter SDK >= 3.10.0
- Android Studio (含 Android SDK)
- JDK 11 或更高
- 最低 Android API 21 (Android 5.0)

## 构建步骤

### 1. 安装 Flutter SDK

从官网下载并安装 Flutter SDK：
https://docs.flutter.dev/get-started/install

### 2. 配置环境变量

将 Flutter 的 `bin` 目录添加到 PATH 中。

### 3. 验证环境

```bash
flutter doctor
```
确保所有项都正常（Android toolchain 必须正常）。

### 4. 进入项目目录

```bash
cd mht_to_pdf_app
```

### 5. 安装依赖

```bash
flutter pub get
```

### 6. 配置 Android SDK 路径

复制 `android/local.properties.example` 为 `android/local.properties`，然后修改：

```properties
sdk.dir=/path/to/your/Android/Sdk
flutter.sdk=/path/to/your/flutter
```

或者直接让 Flutter 自动生成（首次运行 `flutter run` 时会自动创建）。

### 7. 构建 APK

#### Debug 版本（快速测试）
```bash
flutter build apk --debug
```
输出位置：`build/app/outputs/flutter-apk/app-debug.apk`

#### Release 版本（正式发布）
```bash
flutter build apk --release
```
输出位置：`build/app/outputs/flutter-apk/app-release.apk`

### 8. 安装到手机

```bash
flutter install
```

或者将 APK 文件直接传到手机上安装。

## 使用方法

1. 打开应用
2. 点击「添加文件」选择一个或多个 MHT/MHTML 文件
3. （可选）点击「更改」修改输出目录
4. 点击「开始转换」
5. 等待转换完成
6. 点击文件右侧的图标查看生成的 PDF

## 技术说明

### 核心原理
1. Flutter UI 层负责文件选择、列表管理、进度展示
2. 通过 MethodChannel 调用 Android 原生代码
3. Android 端使用 WebView 加载 MHT 文件
4. 利用 WebView 的 `createPrintDocumentAdapter()` 生成 PDF
5. 输出为 A4 尺寸的 PDF 文件

### 为什么用 WebView 方案？
- 完美还原 MHT 中的 HTML/CSS/JS 渲染
- 支持复杂页面布局和样式
- 系统原生 API，稳定可靠
- 不需要额外的 PDF 渲染库

## 常见问题

### Q: 转换失败怎么办？
A: 检查 MHT 文件是否完整，尝试用浏览器打开确认文件有效。

### Q: 生成的 PDF 排版不对？
A: MHT 文件中的页面布局可能需要特定的视口设置，本应用已尽量优化，但复杂页面可能存在差异。

### Q: 支持 iOS 吗？
A: 项目结构是 Flutter 跨平台的，但目前只实现了 Android 端的原生转换逻辑。iOS 需要另外实现 WKWebView 转 PDF 的代码。

## License

MIT
