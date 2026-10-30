import collections
import datetime as dt
import json
from pathlib import Path

root = Path(__file__).parent
raw = (root / 'raw_dump.json').read_text(encoding='utf-8')
header, payload = raw.split('\n=====SPLIT=====\n', 1)
data = json.loads(payload)
tt = data['tt']
session = next(s for s in data['extra']['sl']['sessionVOList'] if str(s['id']) == tt['sessionId'])
first = dt.date.fromisoformat(session['beginDate'])
assert first.weekday() == 0, '学期起始日不是星期一，不能推断周次'
periods = data['extra']['tp']['data'][0]['periodList']
times = {p['smallPeriod']: (p['startTime'], p['endTime']) for p in periods}
nodes, missions, unscheduled = {}, [], []
for record in tt['list']:
    course = record['courseName'].strip()
    code = record.get('courseCode') or course
    if code not in nodes:
        nodes[code] = {'key': f'course-{len(nodes)+1:02}', 'title': course}
    week_bits, period_bits = record.get('teachingWeek'), record.get('period')
    day = record.get('weekDay')
    if not day or not period_bits:
        unscheduled.append((course, week_bits, record.get('id')))
        continue
    assert week_bits and set(week_bits) <= set('01') and set(period_bits) <= set('01')
    day = int(day)
    assert 1 <= day <= 7
    slots = [i + 1 for i, x in enumerate(period_bits) if x == '1']
    assert slots and slots == list(range(slots[0], slots[-1] + 1)), '节次不连续，需人工处理'
    start, end = times[slots[0]][0], times[slots[-1]][1]
    start_min = int(start[:2])*60 + int(start[3:]); end_min = int(end[:2])*60 + int(end[3:])
    assert end_min > start_min
    detail = []
    if record.get('roomName'): detail.append('地点：' + record['roomName'].strip())
    if record.get('instructorName'): detail.append('教师：' + record['instructorName'].strip())
    detail.append(f'第 {slots[0]}–{slots[-1]} 节')
    for week, active in enumerate(week_bits, 1):
        if active != '1': continue
        date = first + dt.timedelta(weeks=week-1, days=day-1)
        assert date <= dt.date.fromisoformat(session['endDate'])
        missions.append({'key': f'class-{record["id"]}-week-{week}', 'nodeKey': nodes[code]['key'], 'title': course,
            'schedule': {'scheduledDate': date.isoformat(), 'timePolicy': 'FIXED', 'fixedStartAt': f'{date.isoformat()}T{start}:00+08:00', 'plannedDurationMinutes': end_min-start_min},
            'executionPlan': {'notes': '；'.join(detail) + f'；第 {week} 周'}})
missions.sort(key=lambda x:x['schedule']['fixedStartAt'])
for course, bits, _ in unscheduled:
    weeks = '、'.join(str(i) for i, bit in enumerate(bits or '', 1) if bit == '1')
    node = next(n for n in nodes.values() if n['title'] == course)
    node['description'] = f'教务另有第 {weeks} 周的课程，但未提供星期、节次或地点，需核实后手动安排。'
package = {'schema':'mission-book.goal-package', 'version':1, 'packageId':f'cqyt-timetable-{tt["sessionId"]}-20261029',
    'goal': {'title': '2026 秋季学期课表', 'description':'来自重庆移通学院智慧教务的课表；按学期首周、教学周和节次展开。'},
    'defaults': {'timeZone':'Asia/Shanghai','plannedDurationMinutes': 45,'verificationPolicy':'SELF_REPORT'},
    'nodes':list(nodes.values()), 'missions':missions}
out = Path.home() / 'Downloads' / 'MissionBook-2026秋季课表.json'
out.write_text(json.dumps(package, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
overlaps=[]
for a,b in zip(missions,missions[1:]):
    aa=dt.datetime.fromisoformat(a['schedule']['fixedStartAt']); bb=dt.datetime.fromisoformat(b['schedule']['fixedStartAt'])
    if aa+dt.timedelta(minutes=a['schedule']['plannedDurationMinutes']) > bb: overlaps.append((a['title'],b['title'],str(bb)))
print('output',out, 'courses',len(nodes),'scheduled',len(missions),'unscheduled',len(unscheduled),'overlaps',len(overlaps))
print('unscheduled', [(ascii(c), w, i) for c,w,i in unscheduled])
for x in overlaps: print('overlap',ascii(str(x)))
print('first-last',missions[0]['schedule']['scheduledDate'],missions[-1]['schedule']['scheduledDate'])
