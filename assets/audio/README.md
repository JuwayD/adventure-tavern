# 音频资源说明

本文件夹用于存放游戏的音频资源。

## 文件夹结构

```
assets/audio/
├── bgm/           # 背景音乐
│   ├── tavern_theme.ogg    # 酒馆主题音乐
│   ├── peaceful_day.ogg    # 平静的一天
│   └── event_music.ogg    # 事件音乐
│
└── sfx/           # 音效
    ├── guest_arrive.ogg    # 客人到达
    ├── guest_served.ogg   # 服务完成
    ├── coin.ogg           # 金币声
    ├── build.ogg          # 建造声
    ├── card_select.ogg    # 卡牌选择
    ├── day_change.ogg     # 日期变化
    ├── good_event.ogg     # 好事件
    ├── bad_event.ogg      # 坏事件
    ├── ui_click.ogg       # UI点击
    └── error.ogg          # 错误提示
```

## 格式要求

- **背景音乐**: OGG Vorbis 格式, 建议 128-256kbps
- **音效**: WAV 或 OGG 格式, 建议 44.1kHz, 16-bit

## 备注

如果音频文件不存在，AudioManager 会使用合成音效作为后备方案。
