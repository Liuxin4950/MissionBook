from pathlib import Path
from html import escape
from math import atan2, cos, sin, pi
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parents[2] / 'output' / 'blog'
OUT.mkdir(parents=True, exist_ok=True)
C = dict(bg='#F7F5ED', paper='#FFFEFA', ink='#2B2B27', muted='#6F6F62',
         green='#4A6A57', line='#DCD8CC', soft='#EDF1E9', blue='#EAF0F4')
FONTS = {}

def face(size, mono=False):
    key = size, mono
    if key not in FONTS:
        FONTS[key] = ImageFont.truetype('C:/Windows/Fonts/' + ('consola.ttf' if mono else 'msyh.ttc'), size)
    return FONTS[key]

class Canvas:
    def __init__(self, width, height, title):
        self.w, self.h = width, height
        self.image = Image.new('RGB', (width, height), C['bg'])
        self.draw = ImageDraw.Draw(self.image)
        self.svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
                    f'<title>{escape(title)}</title>']
        self.box(0, 0, width, height, C['bg'], radius=0, stroke=False)

    def box(self, x, y, w, h, fill=None, radius=18, stroke=True):
        fill = fill or C['paper']
        self.draw.rounded_rectangle((x, y, x+w, y+h), radius=radius, fill=fill,
                                    outline=C['line'] if stroke else None, width=2)
        self.svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}"' +
                        (f' stroke="{C["line"]}" stroke-width="2"' if stroke else '') + '/>')

    def text(self, x, y, value, size=28, color=None, mono=False, max_width=None):
        color = color or C['ink']
        font = face(size, mono)
        width = self.draw.textlength(value, font=font)
        if max_width is not None and width > max_width:
            raise ValueError(f'Text overflows: {value}: {width} > {max_width}')
        if x + width > self.w - 25:
            raise ValueError(f'Text leaves canvas: {value}')
        self.draw.text((x, y), value, font=font, fill=color, anchor='lt')
        family = 'Consolas, monospace' if mono else 'Microsoft YaHei, sans-serif'
        self.svg.append(f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" fill="{color}" dominant-baseline="text-before-edge" xml:space="preserve">{escape(value)}</text>')

    def center(self, cx, y, value, size=28, color=None, mono=False):
        width = self.draw.textlength(value, font=face(size, mono))
        self.text(cx-width/2, y, value, size, color, mono)

    def arrow(self, points, color=None, width=3):
        color = color or C['green']
        self.draw.line(points, fill=color, width=width, joint='curve')
        a, b = points[-2], points[-1]
        angle = atan2(b[1]-a[1], b[0]-a[0])
        tip = [b, (b[0]-17*cos(angle-pi/6), b[1]-17*sin(angle-pi/6)),
                  (b[0]-17*cos(angle+pi/6), b[1]-17*sin(angle+pi/6))]
        self.draw.polygon(tip, fill=color)
        pts = ' '.join(f'{x},{y}' for x,y in points)
        self.svg.append(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round"/>')
        pts = ' '.join(f'{x},{y}' for x,y in tip)
        self.svg.append(f'<polygon points="{pts}" fill="{color}"/>')

    def save(self, stem):
        self.image.save(OUT/f'{stem}.png', optimize=True)
        (OUT/f'{stem}.svg').write_text('\n'.join(self.svg+['</svg>']), encoding='utf-8')
        print(OUT/f'{stem}.png')

def dependency_panel(canvas, x, location):
    width = 1000
    canvas.box(x, 260, width, 1015)
    canvas.text(x+38, 297, f'接口放在 {location}/', 42)
    canvas.text(x+40, 361, '箭头表示源码依赖，不是执行顺序', 25, C['muted'])
    left, inner_width = x+40, 920

    canvas.box(left, 418, inner_width, 175)
    canvas.text(left+28, 445, 'application/mission_service.dart', 29, mono=True)
    canvas.text(left+28, 497, f"import '../{location}/mission_repository.dart';", 27, C['green'], True)
    canvas.text(left+28, 541, 'final MissionRepository repository;', 27, mono=True)

    # Both services depend only on the abstract library, not the implementation.
    canvas.arrow([(x+500, 593), (x+500, 708)])
    canvas.box(x+342, 625, 316, 39, C['paper'], 0, False)
    canvas.center(x+500, 630, 'import 纯接口文件', 25, C['green'])

    canvas.box(left, 708, inner_width, 175, C['soft'])
    canvas.text(left+28, 737, f'{location}/mission_repository.dart', 29, C['green'], True)
    canvas.text(left+28, 790, 'MissionRepository', 30, mono=True)
    canvas.text(left+28, 836, 'Future<List<Mission>> getToday();', 27, mono=True)

    # Implements is a source relationship directed toward the interface.
    canvas.arrow([(x+500, 998), (x+500, 883)])
    canvas.box(x+335, 922, 330, 40, C['paper'], 0, False)
    canvas.center(x+500, 929, 'import + implements', 25, C['green'], True)

    canvas.box(left, 998, inner_width, 170, C['blue'])
    canvas.text(left+28, 1025, 'data/sqlite_mission_repository.dart', 29, mono=True)
    canvas.text(left+28, 1078, 'SqliteMissionRepository', 29, mono=True)
    canvas.text(left+28, 1120, 'implements MissionRepository', 27, mono=True)

    note = 'data 模块提供数据访问契约' if location == 'data' else '业务核心拥有契约，data 负责适配'
    canvas.center(x+500, 1204, note, 28, C['green'])

first = Canvas(2200, 1510, 'Repository 接口放 data 与 domain 的源码依赖对比')
first.text(72, 48, 'MISSION BOOK  /  01  SOURCE DEPENDENCIES', 24, C['green'])
first.text(70, 99, '接口换目录，源码依赖怎么变？', 58)
first.text(73, 187, '前提：接口声明相同，仅使用纯 Dart 的 Mission；接口文件不引用数据库或平台库。', 28, C['muted'])
dependency_panel(first, 70, 'data')
dependency_panel(first, 1130, 'domain')
first.text(73, 1326, '相同点：两边的 Service 都只引用接口文件，运行时都可以使用 SQLite 实现或内存实现。', 29)
first.text(73, 1382, '差别：接口由哪个模块拥有，以及项目希望约束怎样的依赖方向。', 29, C['green'])
first.text(73, 1440, 'import / export 决定实际源码依赖；目录不会自动导入全部实现，也不会自动成为独立模块。', 25, C['muted'])
first.save('repository-interface-placement')

second = Canvas(2200, 1300, '两种接口目录方案相同的对象组装与运行过程')
second.text(72, 48, 'MISSION BOOK  /  02  RUNTIME CALLS', 24, C['green'])
second.text(70, 99, '接口位置不同，运行调用过程相同', 58)
second.text(73, 187, '启动代码创建具体对象并注入；Service 通过接口引用调用，真正执行方法的是实现对象。', 28, C['muted'])

second.box(70, 264, 2060, 300)
second.text(110, 298, '启动组装位置 · bootstrap.dart（示意）', 33, C['green'])
second.text(110, 360, '创建 SQLite 实现对象', 27)
second.text(500, 356, 'final repository = SqliteMissionRepository(database);', 32, mono=True, max_width=1560)
second.text(110, 430, '通过构造函数传给服务', 27)
second.text(500, 427, 'final service = MissionService(repository);', 32, mono=True, max_width=1560)
second.text(110, 505, 'repository 是同一个具体对象；传入 Service 时，不会变成一个“接口对象”。', 28, C['muted'])

second.arrow([(1100, 564), (1100, 625), (400, 625), (400, 695)])
second.box(70, 695, 680, 250)
second.text(105, 731, 'MissionService', 37, mono=True)
second.text(105, 792, '字段类型：MissionRepository', 29)
second.text(105, 846, '字段指向的对象：', 27, C['muted'])
second.text(105, 886, 'SqliteMissionRepository', 29, C['green'], True)

second.box(970, 695, 620, 250, C['soft'])
second.text(1005, 732, 'SqliteMissionRepository', 32, mono=True)
second.text(1005, 794, '执行实际的 getToday() 方法', 29)
second.text(1005, 850, '在这里访问 SQLite / Drift', 28, C['muted'])

second.box(1805, 695, 325, 250, C['blue'])
second.center(1967, 757, 'SQLite', 45, mono=True)
second.center(1967, 840, '本地数据库', 29)

second.arrow([(750, 820), (970, 820)])
second.center(860, 754, '调用', 27, C['green'])
second.center(860, 870, 'getToday()', 25, mono=True)
second.arrow([(1590, 820), (1805, 820)])
second.center(1697, 764, '查询', 27, C['green'])

second.arrow([(1967, 945), (1967, 1040), (400, 1040), (400, 945)], C['muted'], 2)
second.box(830, 1014, 600, 48, C['bg'], 0, False)
second.center(1130, 1021, '任务查询结果沿调用链返回', 28, C['muted'])
second.text(73, 1132, '接口定义能调用什么；注入决定由哪个对象执行；目录位置表达契约归属。', 32, C['green'])
second.text(73, 1205, '示意代码用于解释机制；能否替换实现，还需保证接口契约和行为一致。', 25, C['muted'])
second.save('repository-runtime-flow')
