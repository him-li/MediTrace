# MediTrace

MediTrace 是一个用于记录药物服用时间与估算体内剩余量的多平台项目。

## 项目结构

```text
MediTrace/
├── ios/    SwiftUI iOS + macOS App
└── web/    Next.js App Router + TypeScript + HeroUI Web App
```

## 功能

- 创建药物并设置单次剂量、单位、达到峰值时间和半衰期
- 一键记录当前服用，也可以补录任意时间的服药记录
- 按一阶消除模型叠加每次服药的剩余量
- 使用 Swift Charts 显示过去与未来的估算变化
- 所有数据仅保存在设备本地
- 使用 iOS 26 AlarmKit 创建固定时长或低于指定估算量时触发的系统闹钟
- 支持自定义延长时间；停止闹钟后要求记录新的服药剂量

## 计算模型

服药后的估算量会在用户提供的峰值时间（Tmax）内线性上升，达到峰值后，每次剂量在消除时间 `t` 后的估算剩余量为：

```
remaining = dose × 0.5 ^ (t / halfLife)
```

某一时刻的总量是该时刻之前所有剂量的剩余量之和。由于应用没有分布容积、生物利用度、吸收速率等临床参数，界面使用“估算体内剩余量”，而不将结果描述成真实血药浓度。

## 本地化

界面支持简体中文、繁体中文、英文、希伯来文和阿拉伯文，并跟随设备语言。希伯来文与阿拉伯文会自动采用从右到左布局。

## 运行 iOS / macOS App

使用 Xcode 27 或更新版本打开 `ios/MediTrace.xcodeproj`：

- iOS：选择 iOS 26+ 模拟器或设备。提醒使用 AlarmKit。
- macOS：选择 `My Mac`。提醒使用 macOS 通知中心。

首次添加提醒时，系统会请求相应权限。macOS 没有与 iOS AlarmKit 等价的公开系统闹钟 API，因此 Mac 版使用带声音和操作按钮的系统通知；“忽略并延长”会重新安排通知，“停止并记录”会激活 App 并要求录入新剂量。

## 运行 Web App

```bash
cd web
npm install
npm run dev
```

Web 工程使用 Next.js App Router、React、TypeScript、HeroUI v3 和 Tailwind CSS 4。

> 本应用只用于记录和趋势估算，不提供医疗建议，也不能用于调整用药。请严格遵照医生或药师的指导。
