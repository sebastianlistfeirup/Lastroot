from pathlib import Path
import sys, json, re, html
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph, Table, TableStyle, Spacer, Flowable, KeepTogether, Image
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.colors import HexColor, Color, white
from reportlab.lib.enums import TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from pypdf import PdfReader, PdfWriter
from pypdf.annotations import Link
ROOT=Path(__file__).resolve().parents[1]
def get_games():
    return {'lastroot':json.loads((ROOT/'design/bible.json').read_text())}

OUT=ROOT/'pdf'; OUT.mkdir(exist_ok=True)
for n,p in [('Body','DejaVuSans.ttf'),('Bold','DejaVuSans-Bold.ttf'),('Mono','DejaVuSansMono.ttf')]:
    pdfmetrics.registerFont(TTFont(n,'/usr/share/fonts/truetype/dejavu/'+p))
pdfmetrics.registerFontFamily('Body',normal='Body',bold='Bold',italic='Body',boldItalic='Bold')
W,H=595.276,841.89; M=44; BW=W-2*M
INK=HexColor('#172438'); MUTED=HexColor('#607184'); LINE=HexColor('#DFE5EC')
def esc(s):
    s=s.replace('\u2011','-').replace('\u2013','-').replace('\u2014','-')
    return html.escape(s).replace('\n','<br/>')
def style(n,size=9.3,lead=14,**kw):
    opts=dict(fontName='Body',fontSize=size,leading=lead,textColor=INK,spaceAfter=0)
    opts.update(kw)
    return ParagraphStyle(n,**opts)

def draw_header(c,doc,pageno,title):
    c.setFillColor(white);c.rect(0,0,W,H,fill=1,stroke=0)
    a=HexColor('#'+doc['accent']); c.setFillColor(a);c.rect(M,H-35,28,3,fill=1,stroke=0)
    c.setFillColor(MUTED);c.setFont('Bold',7.3);c.drawString(M+37,H-35,doc['name'])
    c.setFont('Body',7);c.drawRightString(W-M,H-35,'UDVIKLINGSBIBEL / V2.0')
    c.setStrokeColor(LINE);c.line(M,44,W-M,44)
    c.setFillColor(MUTED);c.setFont('Body',6.7);c.drawString(M,30,'SPEC_READY  |  19.10.2026  |  Spildesign og verificerbar produktionsplan')
    c.setFont('Bold',7.5);c.drawRightString(W-M,29,str(pageno))

def cover(c,doc):
    a=HexColor('#'+doc['accent']);c.setFillColor(HexColor('#111A29'));c.rect(0,0,W,H,fill=1,stroke=0)
    c.saveState();c.rect(0,0,0,0,stroke=0);c.drawImage(str(ROOT/'references/REF_05.jpeg'),-53,0,width=702,height=H,mask='auto');c.setFillColor(Color(.035,.07,.10,alpha=.82));c.rect(0,0,W,H,fill=1,stroke=0);c.restoreState()
    c.setFillColor(a);c.rect(0,H-16,W,16,fill=1,stroke=0)
    c.setFont('Bold',9);c.setFillColor(HexColor('#C9D6E6'));c.drawString(M,H-76,'SPILDESIGN / GODOT / SYNTY + POLYPERFECT')
    name=doc['name'];sz=46 if len(name)<15 else 31
    p=Paragraph(esc(name),style('cover',sz,sz+8,textColor=white,fontName='Bold'))
    ww,hh=p.wrap(BW,180);p.drawOn(c,M,H-153-hh)
    p=Paragraph(esc(doc['subtitle']),style('subtitle',19,27,textColor=HexColor('#D9E3EE')))
    ww,hh=p.wrap(BW-15,100);p.drawOn(c,M,H-270-hh)
    # A visual system motif, not a screenshot or claim of shipped software.
    for i,(label,sub) in enumerate([('FERIE','Dagplan · én kodeagent'),('PRODUKTION','4 faser · 36 opgaver'),('KVALITET','Gameplay · animation · test')]):
        x=M+i*(BW/3+1); c.setFillColor(Color(a.red,a.green,a.blue,alpha=0.35+i*.1));c.roundRect(x,250,BW/3-10,108,8,fill=1,stroke=0)
        c.setFillColor(white);c.setFont('Bold',10);c.drawString(x+14,322,label)
        pp=Paragraph(esc(sub),style('card',9,14,textColor=HexColor('#D9E3EE')));pp.wrap(BW/3-34,60);pp.drawOn(c,x+14,280)
    pp=Paragraph(esc(doc['tagline']),style('tagline',14,21,textColor=white));ww,hh=pp.wrap(BW,80);pp.drawOn(c,M,191-hh)
    c.setFillColor(HexColor('#9FB0C7'));c.setFont('Body',9);c.drawString(M,91,'Version 2.0  /  19. oktober 2026')
    c.setFont('Body',8);c.drawString(M,72,'Fundament -> kvalitetsudsnit -> komplet spil -> udgivelseskandidat')
    c.showPage()

def contents(c,doc,pages):
    draw_header(c,doc,2,'Indhold')
    c.setFillColor(INK);c.setFont('Bold',26);c.drawString(M,H-92,'Indhold og arbejdsvej')
    lead=Paragraph('Start med mandatet. Læs spillets systemer, de fire faser og opgavekortene. Hver bibel er selvstændig. Klik på et kapitel for at gå til siden.',style('toclead',10,15))
    _,hh=lead.wrap(BW,80);lead.drawOn(c,M,H-114-hh)
    half=(len(pages)+1)//2; cw=(BW-25)/2; rowh=20.0
    for i,p in enumerate(pages):
        col=i//half;row=i%half;x=M+col*(cw+25);y=H-187-row*rowh
        title=p['title'];pp=Paragraph(esc(title),style('tocitem',7.4,8.7))
        _,th=pp.wrap(cw-27,22);pp.drawOn(c,x,y-th+7)
        c.setFillColor(HexColor('#'+doc['accent']));c.setFont('Bold',8);c.drawRightString(x+cw,y,str(i+3))
        c.linkRect('',f'p{i+3}',(x,y-11,x+cw,y+9),relative=0,thickness=0)
        c.setStrokeColor(LINE);c.line(x,y-12,x+cw,y-12)
    c.showPage()

class GameMap(Flowable):
    def __init__(self,game,accent):
        Flowable.__init__(self);self.game=game;self.accent=accent;self.width=BW;self.height=215
    def draw(self):
        c=self.canv;w=self.width;h=self.height
        c.setFillColor(HexColor('#12212D'));c.roundRect(0,0,w,h,8,fill=1,stroke=0)
        def txt(x,y,t,s=8,col=white):
            c.setFillColor(col);c.setFont('Bold',s);c.drawString(x,y,t)
        def box(x,y,ww,hh,t,col):
            c.setFillColor(HexColor(col));c.roundRect(x,y,ww,hh,4,fill=1,stroke=0)
            pp=Paragraph(esc(t),style('map',8,11,textColor=white,fontName='Bold'));_,th=pp.wrap(ww-14,hh-8);pp.drawOn(c,x+7,y+(hh-th)/2)
        def path(points,col='#AFC3CF',dash=False):
            c.setStrokeColor(HexColor(col));c.setLineWidth(3);c.setDash(4,3) if dash else c.setDash()
            p=c.beginPath();p.moveTo(*points[0])
            for q in points[1:]:p.lineTo(*q)
            c.drawPath(p);c.setDash()
        txt(15,h-22,'LEVELDESIGN / FUNKTION FØR DEKORATION',8)
        if self.game=='genesis':
            path([(95,78),(225,78),(225,148),(360,148)],'#5DC9C2')
            path([(225,78),(365,78),(365,40)],'#E5BF75')
            box(26,48,123,60,'ARK + ROBOTHUB\nStart / nødreserve','#266F79')
            box(170,118,109,50,'VAND + STRØM\nForsyningsdistrikt','#326C90')
            box(316,118,160,50,'HABITAT + OMSORG\nBeskyttet zone','#637A45')
            box(306,27,170,56,'MINE + VÆRKSTED\nAfstand koster kapacitet','#8A6240')
            txt(27,20,'3 landingssites pr. biome; denne skitse viser ét layout.',7,HexColor('#C0CFD8'))
        elif self.game=='dead':
            path([(66,53),(66,143),(230,143),(230,53),(425,53),(425,143)],'#8EB4B7')
            path([(66,53),(425,53)],'#E6B47B',True)
            box(19,27,94,42,'INDSÆTTELSE','#37667C')
            box(19,119,108,53,'VÆRKSTED\nLang / sikker rute','#5D6F79')
            box(177,117,116,56,'GENERATOR\nLys + signalrisiko','#A16B32')
            box(363,27,119,43,'RELÆRUM\nKort / mørk rute','#654A63')
            box(363,120,119,52,'EKSTRAKTION\nVarslet perimeter','#39786A')
            txt(170,83,'Svejsbar sidedør',7,HexColor('#E6B47B'))
            txt(155,13,'Besøg 2 bevarer døre, strøm og nøglehandlinger.',6.8,HexColor('#C0CFD8'))
        else:
            path([(63,120),(202,120),(202,45),(350,45),(350,140),(445,140)],'#E3C786')
            path([(63,120),(63,45),(202,45)],'#8AAF90',True)
            box(18,100,105,64,'KONTROLPOST\nLær sigte + cover','#5D6D45')
            box(152,100,104,64,'JEEP\nFartskifte','#697B87')
            box(152,22,126,51,'DEPOT\nErobr / ødelæg','#9B713B')
            box(304,22,95,51,'BRO\nReparér / spræng','#4C7678')
            box(352,112,130,53,'UDTRÆK\nFå holdet hjem','#8B5345')
            txt(20,22,'Flankerute',7,HexColor('#ABC8B2'))
        c.setStrokeColor(HexColor('#334854'));c.setLineWidth(.5)
        c.roundRect(0,0,w,h,8,fill=0,stroke=1)

def blocks_for(p,doc,scale=1):
    a=HexColor('#'+doc['accent']);b=[]
    b.append(Paragraph(esc(p['title']),style('title',24*scale,29*scale,fontName='Bold')));b.append(Spacer(1,10))
    b.append(Paragraph(esc(p['lead']),style('lead',10.5*scale,15.5*scale,textColor=MUTED)));b.append(Spacer(1,17))
    for el in p['blocks']:
        typ=el['type']
        if typ in ['section','bullets']:
            b.append(Paragraph(esc(el['title']),style('section',10.7*scale,14.5*scale,fontName='Bold',textColor=a)));b.append(Spacer(1,4))
            if typ=='section':
                b.append(Paragraph(esc(el['text']),style('body',10.0*scale,15.0*scale,wordWrap='LTR',splitLongWords=True)))
            else:
                for it in el['items']:
                    b.append(Paragraph('• '+esc(it),style('bullet',10.0*scale,15.0*scale,leftIndent=9,firstLineIndent=-9)));b.append(Spacer(1,3))
            b.append(Spacer(1,12))
        elif typ=='callout':
            pp=Paragraph(esc(el['text']),style('call',9.25*scale,14.2*scale,fontName='Bold',textColor=a))
            t=Table([[pp]],colWidths=[BW]);t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),HexColor('#F0F4F8')),('BOX',(0,0),(-1,-1),0.5,LINE),('LEFTPADDING',(0,0),(-1,-1),12),('RIGHTPADDING',(0,0),(-1,-1),12),('TOPPADDING',(0,0),(-1,-1),10),('BOTTOMPADDING',(0,0),(-1,-1),10)]));b.append(t);b.append(Spacer(1,10))
        elif typ=='table':
            hdr=[Paragraph(esc(x),style('th',8.5*scale,12*scale,fontName='Bold',textColor=white)) for x in el['headers']]
            data=[hdr]+[[Paragraph(esc(x),style('td',9.0*scale,13.3*scale)) for x in row] for row in el['rows']]
            widths=el.get('widths') or [1/len(hdr)]*len(hdr)
            t=Table(data,colWidths=[BW*v for v in widths],hAlign='LEFT')
            t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),a),('ROWBACKGROUNDS',(0,1),(-1,-1),[HexColor('#F0F4F8'),white]),('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),9),('RIGHTPADDING',(0,0),(-1,-1),9),('TOPPADDING',(0,0),(-1,-1),7*scale),('BOTTOMPADDING',(0,0),(-1,-1),7*scale),('LINEBELOW',(0,0),(-1,-1),0.3,LINE)]));b.append(t);b.append(Spacer(1,14))
        elif typ=='reference_image':
            from PIL import Image as PILImage
            file=ROOT/el['path'];iw,ih=PILImage.open(file).size;factor=min(BW/iw,400/ih)
            b.extend([Image(str(file),width=iw*factor,height=ih*factor),Spacer(1,14)])
        elif typ=='diagram':b.extend([GameMap(el['game'],a),Spacer(1,13)])
    return b

LAYOUT=[]
def make_pdf(doc,pages,path):
    c=canvas.Canvas(str(path),pagesize=(W,H),pageCompression=1)
    c.setTitle(doc['name']+' - Udviklingsbibel v2.0');c.setAuthor('Codex');c.setSubject('Produkt, design, arkitektur, implementering og autonom udvikling')
    cover(c,doc);contents(c,doc,pages)
    for i,p in enumerate(pages,3):
        draw_header(c,doc,i,p['title']);c.bookmarkPage(f'p{i}');c.addOutlineEntry(p['title'],f'p{i}',level=0,closed=False)
        chosen=None
        for sc in [1,.97,.94,.91,.88]:
            bs=blocks_for(p,doc,sc); heights=[f.wrap(BW,H)[1] for f in bs];total=sum(heights)
            if total<=H-120:chosen=(bs,heights,sc,total);break
        if not chosen:raise RuntimeError(f'Page overflow: {doc["name"]} / {p["title"]} {total}')
        bs,heights,sc,total=chosen;y=H-70
        for f,hh in zip(bs,heights):y-=hh;f.drawOn(c,M,y)
        LAYOUT.append({'doc':doc['name'],'page':i,'title':p['title'],'scale':sc,'bottom':round(y,1),'height':round(total,1)})
        c.showPage()
    c.save();return len(pages)+2

def to_md(doc,pages):
    out=[f'# {doc["name"]}\n\n{doc["subtitle"]}\n\nVersion 2.0 | 2026-10-19 | SPEC_READY\n']
    for p in pages:
        out+=[f'\n## {p["title"]}\n\n{p["lead"]}\n']
        for e in p['blocks']:
            if e['type']=='section':out += [f'\n### {e["title"]}\n\n{e["text"]}\n']
            elif e['type']=='bullets':out += [f'\n### {e["title"]}\n\n'+'\n'.join('- '+x for x in e['items'])+'\n']
            elif e['type']=='callout':out += ['\n> '+e['text']+'\n']
            elif e['type']=='table':out += ['\n| '+' | '.join(e['headers'])+' |\n| '+' | '.join(['---']*len(e['headers']))+' |\n'+'\n'.join('| '+' | '.join(row)+' |' for row in e['rows'])+'\n']
            elif e['type']=='reference_image':out += ['\n![Reference](../'+e['path']+')\n']
            elif e['type']=='diagram':out += ['\n[Leveldesignskitse findes i PDF. Skitsen er en plan, ikke et gameplaybillede.]\n']
    return '\n'.join(out)

def main():
    games=get_games();counts={}
    dd=ROOT/'docs';dd.mkdir(exist_ok=True)
    for key,doc in games.items():
        pages=doc['all_pages']
        counts[key]=make_pdf(doc,pages,OUT/doc['filename'])
        (dd/(key+'.md')).write_text(to_md(doc,pages),encoding='utf-8')
    (ROOT/'layout_report.json').write_text(json.dumps(LAYOUT,ensure_ascii=False,indent=2))
    (ROOT/'pdf_manifest.json').write_text(json.dumps(counts,indent=2))
    print(json.dumps({'pages':counts,'min_bottom':min(x['bottom'] for x in LAYOUT),'scaled':[x for x in LAYOUT if x['scale']<1]},ensure_ascii=False))
if __name__=='__main__':main()
