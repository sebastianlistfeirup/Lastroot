#!/usr/bin/env python3
"""Validate planning metadata. Does not execute Godot or certify gameplay."""
import argparse,json,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--plan',type=Path,default=Path(__file__).resolve().parents[1]/'plan/tasks.json');p.add_argument('--next',action='store_true');a=p.parse_args()
d=json.loads(a.plan.read_text());ts=d['tasks'];by={t['id']:t for t in ts};errors=[]
if len(ts)!=36 or len(by)!=36:errors.append('Expected 36 unique tasks')
if sorted(set(t['phase'] for t in ts))!=[1,2,3,4]:errors.append('Expected four phases')
valid={'TODO','READY','IN_PROGRESS','VERIFYING','DONE','REWORK','BLOCKED_ENVIRONMENT','DROPPED'}
for t in ts:
    if t['status'] not in valid:errors.append(t['id']+': unknown status')
    for dep in t['depends_on']:
        if dep not in by:errors.append(t['id']+': missing dependency '+dep)
        elif by[dep]['phase']>t['phase']:errors.append(t['id']+': future-phase dependency')
    if t['status']=='DONE':
        if not t.get('last_commit') or not t.get('evidence'):errors.append(t['id']+': DONE requires commit and evidence references')
        if any(by.get(x,{}).get('status')!='DONE' for x in t['depends_on']):errors.append(t['id']+': DONE with unfinished dependency')
visiting=set();visited=set()
def visit(k):
    if k in visiting:errors.append('Cycle at '+k);return
    if k in visited or k not in by:return
    visiting.add(k)
    for dep in by[k]['depends_on']:visit(dep)
    visiting.remove(k);visited.add(k)
for k in by:visit(k)
ready=[]
for t in ts:
    if t['status'] not in {'TODO','READY','REWORK'}:continue
    if not all(by.get(dep,{}).get('status')=='DONE' for dep in t['depends_on']):continue
    if any(q['phase']<t['phase'] and q['status']!='DONE' for q in ts):continue
    ready.append(t['id'])
result={'project':d['project'],'valid':not errors,'task_count':len(ts),'errors':errors,'next_candidates':ready[:3] if a.next else ready,'notice':'Metadata only. Verify actual tests and artifacts before marking DONE.'}
print(json.dumps(result,ensure_ascii=False,indent=2));sys.exit(1 if errors else 0)
