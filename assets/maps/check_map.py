"""Technical export checks and supplied-route overlays, never visual path detection.
Requires Pillow. --expected is mandatory when checking route metadata.
"""
import argparse
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw

MODES = {'walk', 'boat', 'zipline', 'climb', 'floating_steps'}

def point(p, size):
    if not isinstance(p, (list, tuple)) or len(p) != 2:
        raise ValueError('Coordinates must be [x,y]')
    if any(isinstance(v, bool) or not isinstance(v, (int,float)) or not math.isfinite(v) for v in p):
        raise ValueError('Coordinates must be finite numbers')
    if not all(0 <= v < limit for v,limit in zip(p,size)):
        raise ValueError(f'Coordinates outside image: {p}')
    return tuple(p)

def validate_metadata(data, size, expected):
    if not isinstance(data,dict) or data.get('size') != list(size):
        raise ValueError('Metadata must contain actual image size')
    if expected < 1:
        raise ValueError('Requested station count must be positive')
    stops = data.get('stops')
    if not isinstance(stops,list) or any(not isinstance(s,dict) for s in stops):
        raise ValueError('stops must be a list of objects')
    keys=[s.get('key') for s in stops]
    if len(stops)!=expected:
        raise ValueError(f'Expected {expected} declared stops, got {len(stops)}')
    if any(not isinstance(k,str) or not k.strip() for k in keys) or len(set(keys))!=len(keys):
        raise ValueError('Station keys must be unique nonempty strings')
    raw = data.get('path')
    if not isinstance(raw,list) or len(raw)<2:
        raise ValueError('path needs at least two points')
    path = [point(p,size) for p in raw]
    cursor = 0.0
    for stop in stops:
        p = point([stop.get('x'),stop.get('y')],size)
        candidates=[]
        for i,(a,b) in enumerate(zip(path,path[1:])):
            dx,dy=b[0]-a[0],b[1]-a[1]
            length=dx*dx+dy*dy
            t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/length)) if length else 0
            distance=math.dist(p,(a[0]+t*dx,a[1]+t*dy))
            if i+t >= cursor and distance <=32:
                candidates.append((distance,i+t))
        if not candidates:
            raise ValueError(f"{stop['key']} not reached in order by supplied polyline (32px tolerance)")
        cursor=min(candidates)[1]
    segments=data.get('segments',[])
    if not isinstance(segments,list): raise ValueError('segments must be a list')
    end=0
    for s in segments:
        if not isinstance(s,dict): raise ValueError('segment must be an object')
        a,b=s.get('start'),s.get('end')
        if type(a) is not int or type(b) is not int or a!=end or not a<b<len(path):
            raise ValueError('Segments must cover consecutive path-index ranges, sharing endpoints')
        if s.get('mode') not in MODES or s.get('visibility') not in {'visible','occluded'}:
            raise ValueError('Invalid segment mode or visibility')
        end=b
    if segments and end!=len(path)-1: raise ValueError('Segments must cover entire path')
    notes=data.get('review_notes',[])
    if not isinstance(notes,list) or any(not isinstance(n,str) for n in notes):
        raise ValueError('review_notes must be a list of strings')
    return stops,path,segments,notes

def draw_overlay(image,destination,stops,path,segments):
    canvas=image.convert('RGB');draw=ImageDraw.Draw(canvas)
    segments=segments or [dict(start=0,end=len(path)-1,mode='walk',visibility='visible')]
    for s in segments:
        points=path[s['start']:s['end']+1]
        if s['visibility']=='occluded':
            for a,b in zip(points,points[1:]):
                length=math.dist(a,b)
                for offset in range(0,math.ceil(length),16):
                    t,u=offset/length,min(1,(offset+8)/length)
                    draw.line([(a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])),(a[0]+u*(b[0]-a[0]),a[1]+u*(b[1]-a[1]))],fill='#ff3470',width=4)
        else: draw.line(points,fill='#ff3470',width=4)
        if s['mode']!='walk':
            draw.text(points[len(points)//2],s['mode'],fill='white',stroke_width=2,stroke_fill='black')
    for i,s in enumerate(stops,1):
        x,y=s['x'],s['y'];draw.ellipse((x-13,y-13,x+13,y+13),fill='#ff3470',outline='white',width=2)
        draw.text((x+16,y-10),f"{i}: {s['key']}",fill='white',stroke_width=2,stroke_fill='black')
    draw.text((16,16),'REVIEW: supplied route, not verified terrain; dashed = occluded',fill='white',stroke_width=2,stroke_fill='black')
    destination.parent.mkdir(parents=True,exist_ok=True);canvas.save(destination)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('images',nargs='+',type=Path)
    parser.add_argument('--route-json',type=Path)
    parser.add_argument('--expected',type=int)
    parser.add_argument('--overlay-dir',type=Path)
    args=parser.parse_args()
    if args.route_json and (len(args.images)!=1 or args.expected is None):
        parser.error('--route-json requires one image and explicit --expected')
    if args.overlay_dir and not args.route_json:
        parser.error('Overlay requires metadata; there is no automatic image detection')
    failed=False
    for filename in args.images:
        try:
            with Image.open(filename) as image:
                image.load();w,h=image.size
                if image.format!='WEBP' or w<1920 or h<1080 or w*9!=h*16:
                    raise ValueError('Export must be WebP, 16:9, at least 1920x1080')
                if filename.stat().st_size>=2_000_000: raise ValueError('Export must be below 2 MB')
                if args.route_json:
                    data=json.loads(args.route_json.read_text(encoding='utf-8-sig'))
                    stops,path,segments,notes=validate_metadata(data,image.size,args.expected)
                    if args.overlay_dir:
                        dest=args.overlay_dir/f'{filename.stem}-route-check.png'
                        if dest.resolve() in {filename.resolve(),args.route_json.resolve()}:
                            raise ValueError('Overlay must not overwrite input')
                        draw_overlay(image,dest,stops,path,segments)
                    print(f'TECHNICAL OK {filename.name}: {len(stops)} declared stops (not detected)')
                    for note in notes: print(f'REVIEW NOTE: {note}')
                else: print(f'TECHNICAL OK {filename.name}: export only, no station check')
                print('VISUAL REVIEW REQUIRED: count actual spaces, trace connections, check levels and shortcuts.')
        except (OSError,ValueError,TypeError,KeyError) as error:
            print(f'FAIL {filename}: {error}');failed=True
    raise SystemExit(1 if failed else 0)

if __name__=='__main__': main()
