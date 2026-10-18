from pathlib import Path
from html import escape
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parents[2] / 'output' / 'blog'
OUT.mkdir(parents=True, exist_ok=True)
W, H = 2200, 1460
C = dict(bg='#F7F5ED', panel='#FFFEFA', ink='#2B2B27', muted='#6F6F62',
         green='#4A6A57', rule='#DEDACE', soft='#EDF1E9')
im = Image.new('RGB', (W, H), C['bg'])
d = ImageDraw.Draw(im)
svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
       '<title>Mission Book 两种目录组织方式对比</title>',
       '<desc>左侧为按页面划分功能模块的方案示意，右侧为当前选择的共享业务分层、表现层按页面组织方案。目录树不表示代码依赖方向。</desc>']
fonts = {}

def font(size, mode='normal'):
    key = size, mode
    if key not in fonts:
        filename = {'normal': 'msyh.ttc', 'bold': 'msyh.ttc', 'mono': 'consola.ttf'}[mode]
        fonts[key] = ImageFont.truetype(str(Path('C:/Windows/Fonts') / filename), size)
    return fonts[key]

def rect(x, y, w, h, fill, radius=0, stroke=None):
    if radius:
        d.rounded_rectangle((x, y, x+w, y+h), radius=radius, fill=fill, outline=stroke, width=2)
    else:
        d.rectangle((x, y, x+w, y+h), fill=fill, outline=stroke, width=2)
    svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}"'+
               (f' stroke="{stroke}" stroke-width="2"' if stroke else '')+'/>' )

def text(x, y, value, size=28, color=None, mode='normal', max_width=None):
    color = color or C['ink']
    face = font(size, mode)
    width = d.textlength(value, font=face)
    if max_width is not None and width > max_width:
        raise ValueError(f'Text overflows: {value}: {width} > {max_width}')
    d.text((x, y), value, font=face, fill=color, anchor='lt')
    family = 'Consolas, monospace' if mode == 'mono' else 'Microsoft YaHei, sans-serif'
    weight = '400'
    svg.append(f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" font-weight="{weight}" fill="{color}" dominant-baseline="text-before-edge" xml:space="preserve">{escape(value)}</text>')

rect(0, 0, W, H, C['bg'])
text(74, 55, 'MISSION BOOK  /  ARCHITECTURE', 24, C['green'])
text(70, 103, '两种目录组织方式', 60, mode='bold')
text(73, 186, '同一套任务、目标与执行记录，如何组织代码？', 28, C['muted'])

left = [
 ('lib/', ''),
 ('├── main.dart', ''),
 ('├── app.dart', ''),
 ('├── core/', '通用基础'),
 ('└── features/', ''),
 ('    ├── today/', '今天'),
 ('    │   ├── domain/', '功能内领域定义'),
 ('    │   ├── application/', '功能内业务编排'),
 ('    │   ├── data/', '功能内数据实现'),
 ('    │   └── presentation/', '功能内页面与交互'),
 ('    ├── goals/', '目标'),
 ('    │   ├── domain/', ''),
 ('    │   ├── application/', ''),
 ('    │   ├── data/', ''),
 ('    │   └── presentation/', ''),
 ('    ├── history/', '历史'),
 ('    │   └── ...', ''),
 ('    └── me/', '我的'),
 ('        └── ...', ''),
]
right = [
 ('lib/', ''),
 ('├── main.dart', ''),
 ('├── app.dart', ''),
 ('├── core/', '通用基础'),
 ('├── domain/', '共享业务核心'),
 ('│   ├── models/', 'Mission、Goal 等'),
 ('│   └── repositories/', '数据访问抽象'),
 ('├── application/', '共用业务编排'),
 ('├── data/', '存储与外部实现'),
 ('└── presentation/', '表现层'),
 ('    ├── widgets/', '公共组件'),
 ('    ├── shell/', '导航外壳'),
 ('    └── pages/', ''),
 ('        ├── today/', '今天'),
 ('        ├── goals/', '目标'),
 ('        ├── history/', '历史'),
 ('        └── me/', '我的'),
]

def panel(x, title, subtitle, rows, chosen=False):
    width = 1000
    rect(x, 255, width, 1055, C['panel'], 22, C['rule'])
    text(x+38, 290, title, 40, mode='bold', max_width=width-76)
    text(x+40, 352, subtitle, 25, C['muted'], max_width=width-80)
    rect(x+39, 399, width-78, 2, C['rule'])
    for i, (path, label) in enumerate(rows):
        y = 425 + i*41
        highlight = chosen and i in (4, 7, 8)
        if highlight:
            rect(x+25, y-4, width-50, 40, C['soft'], 6)
        ink = C['green'] if highlight or path == 'lib/' else C['ink']
        text(x+42, y, path, 31, ink, 'mono', 560)
        if label:
            text(x+620, y+2, label, 25, C['green'] if highlight else C['muted'], max_width=340)
    rect(x+39, 1228, width-78, 2, C['rule'])
    footer = '业务规则共用，页面状态与组件就地组织' if chosen else '共享模型与跨功能依赖，需要明确归属'
    text(x+40, 1252, footer, 26, C['green'], max_width=width-80)

panel(70, 'A  按功能分组', 'Feature-first · 将页面划作功能模块的示意', left)
panel(1130, 'B  共享分层 + 页面内聚', 'Layer-first + 页面模块化 · 当前选择', right, True)
text(73, 1340, '左侧展示本次讨论中的页面划分方式；Feature-first 也可以设置共享领域模块。', 25, C['muted'], max_width=W-146)
text(73, 1385, '目标目录示意，不代表代码依赖方向，也不表示全部功能已经实现。', 25, C['muted'], max_width=W-146)
svg.append('</svg>')
OUT.mkdir(parents=True, exist_ok=True)
im.save(OUT / 'architecture-comparison.png', optimize=True)
(OUT / 'architecture-comparison.svg').write_text('\n'.join(svg), encoding='utf-8')
print(f'PNG: {OUT / "architecture-comparison.png"}')
print(f'SVG: {OUT / "architecture-comparison.svg"}')
