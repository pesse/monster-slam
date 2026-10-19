"""Revision 4: concept colours, full-height grain and shared concept rail.
Run from any directory: python path/to/sources/export.py
All writes are confined to folder_tabs/. Existing window assets are read only.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageStat
import json, hashlib

ROOT = Path(__file__).resolve().parent.parent
WINDOWS = ROOT.parent
SOURCES = ROOT / 'sources'
PREVIEW = ROOT / 'preview'
for directory in (SOURCES, PREVIEW):
    directory.mkdir(parents=True, exist_ok=True)
(SOURCES / '.gdignore').write_bytes(b'')
TITLE = Image.open(WINDOWS / 'title_bar.webp').convert('RGBA')
MATERIAL = Image.open(SOURCES / 'concept-v1.png').convert('RGBA')
# First resample the concept to the actual logical scale, then average a
# text-free rail strip. This preserves the ridge energy at 1:1 pixel size.
LOGICAL_CONCEPT=MATERIAL.resize((1152,round(MATERIAL.height*1152/MATERIAL.width)),Image.Resampling.LANCZOS)
LINE = [tuple(round(c) for c in ImageStat.Stat(LOGICAL_CONCEPT.crop((796,y,1008,y+1))).mean) for y in (172,173,174)]
EXTRACTED_SAMPLES={}
# Exact approved-reference regions, excluding labels from ALL stretch samples.
BOXES = {'normal':(63,240,395,326), 'hover':(741,240,1065,326), 'selected':(1064,240,1410,326)}

def tab(state):
    source = MATERIAL.crop(BOXES[state])
    source.save(SOURCES / f'{state}-concept-region.png')
    xs=(0,28,source.width-28,source.width)
    ys=(0,25,78,86)
    dx=(3,16,112,125)
    dy=(0,12,38,41)
    result=Image.new('RGBA',(128,44))
    for j in range(3):
        for i in range(3):
            patch=source.crop((xs[i],ys[j],xs[i+1],ys[j+1]))
            if i==1:
                # Left blank field before the first glyph, never a text column.
                patch=source.crop((40,ys[j],54,ys[j+1]))
                patch=patch.resize((1,patch.height),Image.Resampling.BOX)
            patch=patch.resize((dx[i+1]-dx[i],dy[j+1]-dy[j]),Image.Resampling.LANCZOS)
            result.paste(patch,(dx[i],dy[j]))
    EXTRACTED_SAMPLES[state]=[result.getpixel((64,yy))[:3] for yy in range(41)]
    for y in range(41):
        for x in range(3,125):
            r,g,b,a=result.getpixel((x,y))
            edge=min(x-3,124-x,y,(x-3+y-8)*0.707,(124-x+y-8)*0.707)
            # Suppress the concept's opaque backdrop outside the chamfer.
            coverage=max(0,min(1,edge+1.0))
            if state=='selected':
                if edge>=4:
                    a=round(3+27*max(0,1-y/40))
                else:
                    a=round(255*coverage)
            elif edge>=4:
                # Match measured source RGB, not a grey lift/desaturation.
                # Invert composition to retain the existing fill alpha 200.
                r,g,b=[max(0,min(255,round((v-(55/255)*bg)/(200/255)))) for v,bg in zip((r,g,b),(8,20,36))]
                a=200
            else:
                # Preserve the sampled silver-blue bevel and its reflections.
                a=round(255*coverage)
            result.putpixel((x,y),(r,g,b,a) if a else (0,0,0,0))
    # Hover-specific light spill sampled from the blue rail shoulder in the
    # concept. The shared baseline itself remains uniform in all four assets.
    if state=='hover':
        reflection=[round(c) for c in ImageStat.Stat(MATERIAL.crop((780,329,800,330))).mean[:3]]
        for y,strength in ((38,0.25),(39,0.6),(40,1.0)):
            for x in range(8,120):
                old=result.getpixel((x,y))
                colour=[round(old[c]*(1-strength)+max(0,min(255,(reflection[c]-(55/255)*bg)/(200/255)))*strength) for c,bg in enumerate((8,20,36))]
                result.putpixel((x,y),(*colour,200))
    for x in range(16,112):
        result.paste(result.crop((64,0,65,41)),(x,0))
    if state=='selected':
        for y in range(12,41):
            for x,alpha in ((0,12),(1,28),(2,55),(125,55),(126,28),(127,12)):
                result.putpixel((x,y),(244,161,30,alpha))
    for y,colour in zip(range(41,44),LINE):
        for x in range(128):
            if state!='selected' or x<3 or x>124:
                result.putpixel((x,y),colour)
    return result

def nine(source, size, margins):
    w,h = size
    l,t,r,b = margins
    sx = (0,l,source.width-r,source.width)
    sy = (0,t,source.height-b,source.height)
    dx = (0,l,w-r,w)
    dy = (0,t,h-b,h)
    out = Image.new('RGBA',size)
    for j in range(3):
        for i in range(3):
            if dx[i+1] == dx[i] or dy[j+1] == dy[j]:
                continue
            tile = source.crop((sx[i],sy[j],sx[i+1],sy[j+1]))
            tile = tile.resize((dx[i+1]-dx[i],dy[j+1]-dy[j]),Image.Resampling.NEAREST)
            out.paste(tile,(dx[i],dy[j]))
    return out

rail_path=ROOT/'rail.webp'
rail_before=hashlib.sha256(rail_path.read_bytes()).hexdigest()
assets = {f'tab_{state}':tab(state) for state in ('normal','hover','selected')}
assets['rail'] = Image.new('RGBA',(32,44))
for yy,colour in zip(range(41,44),LINE):
    for xx in range(32):
        assets['rail'].putpixel((xx,yy),colour)
for name,im in assets.items():
    im.save(SOURCES / f'{name}-raw.png')
    im.save(ROOT / f'{name}.webp',lossless=True,exact=True,method=6)

# Preview is assembled exclusively from exported runtime textures and existing
# title/panel textures. Text is the only overlay; no tab geometry is painted.
assets = {name:Image.open(ROOT/f'{name}.webp').convert('RGBA') for name in assets}
canvas = nine(Image.open(WINDOWS/'window_panel_compact.webp').convert('RGBA'),(1152,648),(32,32,32,32))
# Existing window material remains an independent background layer, never
# stretched into the tab centers. This is also how the in-game face is built.
surface=Image.open(WINDOWS/'window_surface.webp').convert('RGBA')
face=Image.new('RGBA',(1132,628))
for ty in range(0,628,surface.height):
    for tx in range(0,1132,surface.width):
        face.alpha_composite(surface,(tx,ty))
canvas.alpha_composite(face,(10,10))
canvas.alpha_composite(nine(TITLE,(1152,64),(32,8,32,8)),(0,0))
fontpath = WINDOWS.parents[1] / 'fonts/fira_sans/FiraSans-SemiBold.ttf'
font = ImageFont.truetype(str(fontpath),16)
titlefont = ImageFont.truetype(str(fontpath),30)
draw = ImageDraw.Draw(canvas)
draw.text((28,15),'STATISTIK',font=titlefont,fill=(215,227,251,255),stroke_width=0)
# Approved reference is 2172 px wide; 1152/2172 is the comparison scale.
widths = (182,180,173,184)
x, y = 30, 130
positions=[]
for label,state,width in zip(('Überblick','Fortschritt','Aufgaben','Plaketten'),('normal','normal','hover','selected'),widths):
    positions.append(x)
    canvas.alpha_composite(nine(assets[f'tab_{state}'],(width,44),(16,12,16,6)),(x,y))
    color = (255,217,112,255) if state=='selected' else (255,255,255,255)
    draw = ImageDraw.Draw(canvas)
    draw.text((x+width/2,y+21),label,font=font,fill=color,anchor='mm',stroke_width=2,stroke_fill=(4,8,15,255))
    x += width
canvas.alpha_composite(nine(assets['rail'],(1140-x,44),(0,41,0,3)),(x,y))
ImageDraw.Draw(canvas).text((39,200),'Meilensteine',font=ImageFont.truetype(str(fontpath),23),fill=(215,226,250,255))
canvas.save(PREVIEW/'folder-tabs-1152.png')
# Two boundaries: normal/hover and hover/selected, including the open baseline.
crop = (positions[2]-32,y-4,positions[3]+48,y+52)
zoom = canvas.crop(crop)
zoom.resize((zoom.width*4,zoom.height*4),Image.Resampling.NEAREST).save(PREVIEW/'folder-tabs-zoom.png')

checks = {'revision':4,'format':'lossless WebP RGBA (VP8L)','baseline_rgba':LINE,'baseline_source':{'file':'sources/concept-v1.png','resampled_width':1152,'scale':1152/2172,'x_average_after_resampling':[796,1007],'rows_after_resampling':[172,173,174]},'assets':{},'tested_widths':{'min':100,'max':260,'step':1},'rail_sha256':hashlib.sha256(rail_path.read_bytes()).hexdigest(),'vertical_rows_constant_required':False,'text_outline_px':2}
checks['source_colour_measurements']={name:{key:[round(v) for v in ImageStat.Stat(Image.open(SOURCES/f'{name}-concept-region.png').crop(box)).mean] for key,box in {'upper':(40,10,54,18),'middle':(40,40,54,48),'lower':(40,70,54,78),'rim':(40,1,54,3)}.items()} for name in ('normal','hover','selected')}
for name,im in assets.items():
    assert im.size == ((32,44) if name=='rail' else (128,44))
    assert im.mode == 'RGBA'
    assert (ROOT/f'{name}.webp').read_bytes()[12:16] == b'VP8L'
    assert im.tobytes() == Image.open(SOURCES/f'{name}-raw.png').convert('RGBA').tobytes()
    for row,color in zip(range(41,44),LINE):
        for col in range(im.width):
            expected = (0,0,0,0) if name=='tab_selected' and 3<=col<=124 else color
            assert im.getpixel((col,row)) == expected
    if name=='rail':
        assert im.crop((0,0,32,41)).getbbox() is None
    else:
        assert im.crop((0,0,3,41)).getchannel('A').getextrema()[1]<=60
        assert im.crop((125,0,128,41)).getchannel('A').getextrema()[1]<=60
        # Only horizontal stretch columns must remain byte-identical.
        assert len({im.crop((col,0,col+1,44)).tobytes() for col in range(16,112)}) == 1
        assert len({im.crop((0,row,128,row+1)).tobytes() for row in range(12,38)}) > 1
        for yy in range(41):
            for xx in range(3,125):
                inner_distance=min(xx-3,124-xx,yy,(xx-3+yy-8)*0.707,(124-xx+yy-8)*0.707)
                if inner_distance>=4:
                    assert im.getpixel((xx,yy))[3] <= (40 if name=='tab_selected' else 200)
        for width in range(100,261):
            stretched = nine(im,(width,44),(16,12,16,6))
            for row,color in zip(range(41,44),LINE):
                for col in range(width):
                    expected = (0,0,0,0) if name=='tab_selected' and 3<=col<width-3 else color
                    assert stretched.getpixel((col,row)) == expected
    interior = im.crop((16,4,112,38))
    arange = interior.getchannel('A').getextrema()
    if name=='tab_selected': assert arange[1] <= 40
    checks['assets'][name] = {'size':im.size,'mode':im.mode,'alpha_range':im.getchannel('A').getextrema(),'fill_alpha_range':arange}
    if name in ('tab_normal','tab_hover'):
        errors=[]
        for yy in range(4,38):
            pixel=im.getpixel((64,yy))
            composited=[round(pixel[c]*pixel[3]/255+bg*(1-pixel[3]/255)) for c,bg in enumerate((8,20,36))]
            errors.extend(abs(v-target) for v,target in zip(composited,EXTRACTED_SAMPLES[name[4:]][yy]))
        assert max(errors)<=1
        checks['assets'][name]['max_face_rgb_error_over_reference_backdrop']=max(errors)
checks['result']='PASS: dimensions, lossless RGBA roundtrip, face alpha, gutter alpha <=60, identical concept baseline/stubs, selected opening, constant horizontal stretch columns, full-height vertical variation, every integer width 100..260'
original_path=SOURCES/'concept-v1.png'
if original_path.exists():
    original=Image.open(original_path).convert('RGBA')
    scaled=original.resize((1152,round(original.height*1152/original.width)),Image.Resampling.LANCZOS)
    reference=scaled.crop((0,120,1152,180))
    ours=canvas.crop((0,120,1152,180))
    pair=Image.new('RGBA',(1152,164),(6,13,23,255))
    d=ImageDraw.Draw(pair)
    d.text((12,0),'V1 – Original × 1152/2172',font=font,fill='white')
    pair.alpha_composite(reference,(0,20))
    d.text((12,82),'Revision 4 – exportierte Texturen, Fira Sans 16 + Kontur 2',font=font,fill='white')
    pair.alpha_composite(ours,(0,102))
    pair.save(PREVIEW/'compare-v1-1152.png')
    comparison=Image.new('RGBA',(3456,600),(6,13,23,255))
    comparison.alpha_composite(pair,(0,0))
    d=ImageDraw.Draw(comparison)
    d.text((12,176),'V1 – 3× nearest',font=font,fill='white')
    comparison.alpha_composite(reference.resize((3456,180),Image.Resampling.NEAREST),(0,198))
    d.text((12,386),'Revision 4 – 3× nearest',font=font,fill='white')
    comparison.alpha_composite(ours.resize((3456,180),Image.Resampling.NEAREST),(0,408))
    comparison.save(PREVIEW/'compare-v1.png')
    checks['reference_comparison']='compare-v1.png: original concept-v1.png at 1152/2172, exported textures with outlined labels, both additionally 3x nearest'
    checks['reference_scale']=1152/2172
    checks['comparison_tab_widths']=widths
    checks['comparison_sizes']={'compare-v1.png':[3456,600],'compare-v1-1152.png':[1152,164]}
    checks['visual_review']='Revision 4: measured concept steel-blue restored without grey lift; continuous sampled vertical gradient/grain; shared brighter blue concept rail; outline 2px. Horizontal material variation is removed by repeated columns; 44px height, 6px gutters and 16px font differ slightly from scaled painted concept.'
    checks['reference_sha256']=hashlib.sha256(original_path.read_bytes()).hexdigest()
else:
    checks['reference_comparison']='PENDING: attached WSL original not filesystem-readable; sources/tabs-v1.png required for exact comparison'
(PREVIEW/'checks.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
print(json.dumps(checks,ensure_ascii=False,indent=2))
