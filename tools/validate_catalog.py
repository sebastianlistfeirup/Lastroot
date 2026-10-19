#!/usr/bin/env python3
"""Validate source design data. Does not implement or certify the game rules."""
from pathlib import Path
import json
p=Path(__file__).resolve().parents[1]/'design/catalog.json';d=json.loads(p.read_text());cards=d['cards'];ids={x['id'] for x in cards}
assert len(cards)==len(ids)==24
assert sum(x['kind']=='champion' for x in cards)==2
assert sum(x['kind']=='unit' for x in cards)==10
assert len(d['relics'])==8 and len({x['id'] for x in d['relics']})==8
assert len(d['mutations'])==4 and len({x['id'] for x in d['mutations']})==4
assert len(d['normal_battles'])==5
assert sum(d['start_deck']['normal_counts'].values())+1==12
assert set(d['start_deck']['normal_counts'])<=ids
ens={x['id'] for x in d['enemies']}
for b in d['normal_battles']:
 assert [w['turn'] for w in b['waves']]==[1,2,3]
 for w in b['waves']:
  assert all(g['enemy_id'] in ens and g['count']>0 for g in w['groups'])
assert d['boss']['arrival_turn']==5 and d['boss']['escalate_from_turn']==10
assert all(c['cost']>=0 and c['space']>=0 for c in cards)
print(json.dumps({'valid':True,'cards':24,'champions':2,'normal_units':10,'relics':8,'mutations':4,'normal_battles':5,'bosses':1,'notice':'Design metadata only; no gameplay tests executed.'}))
