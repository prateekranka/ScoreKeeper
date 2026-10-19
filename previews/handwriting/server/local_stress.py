from pathlib import Path
import argparse,json,sys,time,hashlib,base64

parser=argparse.ArgumentParser()
parser.add_argument('--root',type=Path,required=True)
parser.add_argument('--manifest',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--only',default='')
parser.add_argument('--mnist',type=Path)
args=parser.parse_args()
sys.path.insert(0,str(args.root/'server'))
from recognise import DigitRecognizer,VERSION
recogniser=DigitRecognizer()
rows=json.loads(args.manifest.read_text())
if args.mnist:
    rows=[{'id':f"mnist-full-{row['index']}",'expected':row['expected'],'png':row['png'],'category':'mnist-full'} for row in json.loads(args.mnist.read_text())]
if args.only:
    rows=[r for r in rows if r['category'] in args.only.split(',')]
result=[]
for i,row in enumerate(rows):
    started=time.monotonic()
    value=recogniser.recognise(base64.b64decode(row['png']) if 'png' in row else Path(row['file']).read_bytes())
    result.append({**{k:v for k,v in row.items() if k!='png'},'result':value,'seconds':time.monotonic()-started})
    if (i+1)%100==0:
        print(json.dumps({'completed':i+1,'total':len(rows)}),flush=True)
valid=[r for r in result if r['expected'] is not None]
accepted=[r for r in result if r['result']['status']=='ready']
correct=[r for r in accepted if r['result'].get('value')==r['expected']]
def summary(group):
    good=[r for r in group if r['expected'] is not None]
    yes=[r for r in group if r['result']['status']=='ready']
    ok=[r for r in yes if r['result'].get('value')==r['expected']]
    return {'samples':len(group),'valid':len(good),'accepted':len(yes),'correct':len(ok),'wrongAccepted':len(yes)-len(ok),'rejected':len(group)-len(yes),'correctCoverage':len(ok)/len(good) if good else None}
report={'version':VERSION,'sourceSHA256':hashlib.sha256((args.root/'server/recognise.py').read_bytes()).hexdigest(),'summary':summary(result),'categories':{c:summary([r for r in result if r['category']==c]) for c in sorted({r['category'] for r in result})},'rows':result}
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='rows'}),flush=True)
