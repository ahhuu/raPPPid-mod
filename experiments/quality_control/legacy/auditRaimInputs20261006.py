"""Read-only input/result checks without starting another MATLAB process.

Writes derived audit JSON only; does not change input data or thresholds.
Run with the workspace dependency Python from the repository root.
"""
from pathlib import Path
import csv,datetime as dt,hashlib,json

ROOT=Path(__file__).resolve().parents[2]
RESULT=ROOT/'RESULTS/PPP_RAIM_ACTIONS_20261005'
def csvrows(path):
    with path.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1048576),b''):h.update(block)
    return h.hexdigest()
def inspect():
    runs=csvrows(RESULT/'action_manifest.csv'); audits=[]; cache={}; reference={}
    for run in runs:
        folder=(ROOT/'WORK'/run['output_dir']).resolve()
        settings=(folder/'settings_summary.txt').read_text(encoding='utf-8',errors='replace').splitlines()
        obs=Path(next(x.split('Obs-File: ',1)[1] for x in settings if x.startswith('  Obs-File: ')))
        if obs not in cache:
            times=[];flags=[]
            with obs.open(encoding='utf-8',errors='strict') as f:
                for line in f:
                    if not line.startswith('>'):continue
                    fields=line[1:].split(); y,m,d,h,minute=map(int,fields[:5]); sec=float(fields[5]);flags.append(int(fields[6]))
                    date=dt.datetime(y,m,d,h,minute)+dt.timedelta(seconds=sec)
                    times.append((date-dt.datetime(1980,1,6)).total_seconds()%604800)
            cache[obs]=(times,flags,digest(obs))
        raw,flags,sha=cache[obs]; diagnostic=csvrows(folder/'raim_epoch_summary.csv')
        times=[float(x['gps_time_sow']) for x in diagnostic]
        assert len(times)==len(raw)==int(run['epochs'])
        delta=max(abs(a-b) for a,b in zip(raw,times))
        assert delta<0.01,(run['device'],delta)
        if run['device'] in reference:assert reference[run['device']]==times
        else:reference[run['device']]=times
        actions=[x for x in diagnostic if int(x['action_code'])>0]
        assert all(float(x['gps_time_sow'])>=float(run['validation_start_sow']) for x in actions)
        assert all(float(x['action_post_ratio'])<=1+1e-10 and float(x['action_geometry_ratio'])<=2+1e-10 for x in actions)
        audits.append(dict(device=run['device'],variant=run['variant'],epochs=len(times),input_sha256=sha,
                           max_raw_time_difference_s=delta,raw_gaps_gt1p5s=sum(b-a>1.5 for a,b in zip(raw,raw[1:])),
                           rinex_epoch_flags=sorted(set(flags)),actions=len(actions),guards_pass=True))
    output=RESULT/'independent_input_action_audit.json'
    output.write_text(json.dumps(audits,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(audits,ensure_ascii=False,indent=2))
if __name__=='__main__':inspect()
