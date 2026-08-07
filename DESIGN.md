---
name: 华云工时查询工具
description: 面向高频工时核对的现代精密仪表界面
colors:
  primary: "#3D5A57"
  primary-strong: "#0F4F42"
  accent: "#B56B45"
  error: "#BA1A1A"
  canvas: "#F5F3EF"
  surface: "#FAFBFA"
  surface-raised: "#FFFFFF"
  graphite: "#17201E"
  graphite-muted: "#59635F"
  outline: "#D7DEDA"
  decimal-muted: "#9AA6A1"
typography:
  headline:
    fontFamily: "Roboto, sans-serif"
    fontSize: "24sp"
    fontWeight: 700
    lineHeight: 1.2
  title:
    fontFamily: "Roboto, sans-serif"
    fontSize: "18sp"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: "Roboto, sans-serif"
    fontSize: "14sp"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "Roboto, sans-serif"
    fontSize: "12sp"
    fontWeight: 500
    lineHeight: 1.2
rounded:
  sm: "6dp"
  md: "8dp"
spacing:
  xs: "4dp"
  sm: "8dp"
  md: "12dp"
  lg: "16dp"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.surface-raised}"
    rounded: "{rounded.md}"
    height: "48dp"
  card:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.graphite}"
    rounded: "{rounded.md}"
    padding: "16dp"
---

# Design System: 华云工时查询工具

## Overview

**Creative North Star: "精密工时仪表"**

界面像一台放在明亮办公桌上的精密计时仪器：结构克制、刻度清楚、触点有真实反馈。轻拟物来自表面的内高光、细边和低幅双层阴影，而不是玻璃、渐变或夸张装饰。信息密度服务于每日核对任务，首屏优先呈现日期、计入工时、完成率和打卡状态。

**Key Characteristics:**

- 冷中性浅底与白色抬升表面
- 石墨文字、玉绿主操作、琥珀提醒
- 8dp 以内圆角和紧凑 4dp 网格
- 数字使用等宽特性，百分位弱化
- 150-220ms 状态动效，不做装饰性循环动画

## Colors

使用克制的中性色承载高密度数据，玉绿只标记主操作和当前选择，琥珀与红色只表达真实状态。

**The Signal Rarity Rule.** 强调色只用于当前选择、主要操作和语义状态，不作为背景装饰。

## Typography

全应用使用 Android 系统 Roboto 字体和 Material 3 类型角色。数据启用等宽数字特性；标题保持紧凑，不在面板内使用展示级大字。

**The Counted Digit Rule.** 完成率显示一位小数。普通工时的两位小数仍完整显示，但百分位统一使用 `decimal-muted` 的浅灰中空字形；日历格内工时直接显示一位小数。末位不参与工时和百分比计算。

## Layout

手机采用底部 NavigationBar，内容区使用 4/8/12/16dp 节奏。页面边距以 12-16dp 为主，关联数据优先横向并列，避免为单个字段创建独立大卡片。扩展宽度时内容限制在可读宽度，不把手机布局无限拉伸。

## Elevation & Depth

深度采用 Material 色调层级和轻拟物双影：浅色上缘高光配合低对比环境阴影，按压时阴影收敛并轻微下沉。禁止高模糊彩色光晕和大面积玻璃效果。

**The Instrument Surface Rule.** 一个数据分组只拥有一个承载表面，禁止卡片嵌套卡片。

## Shapes

主要表面和控件使用 8dp 圆角，小标签使用 6dp；圆形仅用于进度点、头像和明确的图标按钮。形状不随页面任意变化。

## Components

### Buttons

主要按钮为 48dp 玉绿实心 Material 按钮；次要操作使用轮廓或文本按钮。所有触控目标至少 48dp，按压反馈为轻微下沉、色调加深和触觉反馈。

### Cards / Containers

白色表面使用 8dp 圆角、1dp 冷灰边和克制双影。统计面板内部以分隔线、对齐和留白组织，不继续嵌套卡片。

### Inputs / Fields

输入框使用浅灰填充、8dp 圆角和语义色焦点边；错误、禁用、加载状态沿用 Material 3 角色。

### Navigation

紧凑宽度使用三项 Material NavigationBar，当前项用玉绿图标与浅色指示器，未选项保持石墨灰。导航不使用自定义 iOS Home 键隐喻。

### Precision Number

所有两位小数文本通过统一组件生成富文本，最后一位颜色弱化；组件保留语义标签和整体字号，不改变布局宽度。

## Do's and Don'ts

### Do:

- **Do** 让计入工时、目标进度和打卡状态在首屏可扫描。
- **Do** 使用统一计算器和精度文本组件表达公司口径。
- **Do** 用边、光、影和按压位移表达轻拟物材质。

### Don't:

- **Don't** 使用玻璃拟态、背景渐变、装饰圆球或持续脉冲动画。
- **Don't** 在高频操作页面使用大面积空白、超大标题或卡片嵌套。
- **Don't** 用颜色单独表达完成、警告或失败状态。
