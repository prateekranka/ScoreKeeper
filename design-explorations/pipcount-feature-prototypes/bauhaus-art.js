// Editable geometry ported from ClubhouseComponents.swift, not an image asset.
// Coordinates follow KineticBauhausComposition, hub, score, and celebration.
const colors = { paper: '#FFFDF7', ink: '#0B0B0B', blue: '#0D47D9', blueDeep: '#07349F', red: '#EF3340', yellow: '#FFB512', green: '#0A8F4B', coral: '#FF775E' };
const n = value => Number(value.toFixed(3));
const circle = (x, y, radius, color, opacity = 1, extra = '') => `<circle cx="${n(x)}" cy="${n(y)}" r="${n(radius)}" fill="${color}" opacity="${opacity}" ${extra}/>`;
const rect = (x, y, width, height, rotation, color, opacity = 1) => `<rect x="${n(x - width / 2)}" y="${n(y - height / 2)}" width="${n(width)}" height="${n(height)}" fill="${color}" opacity="${opacity}" transform="rotate(${rotation} ${n(x)} ${n(y)})"/>`;
const line = (x1, y1, x2, y2, color, width, opacity = 1, dash = '') => `<path d="M${n(x1)} ${n(y1)}L${n(x2)} ${n(y2)}" fill="none" stroke="${color}" stroke-width="${n(width)}" opacity="${opacity}" ${dash ? `stroke-dasharray="${dash}"` : ''}/>`;
function arc(x, y, radius, start, end, color, width, opacity = 1, dash = '') {
  const point = turn => [x + Math.cos(turn * Math.PI * 2) * radius, y + Math.sin(turn * Math.PI * 2) * radius].map(n).join(' ');
  return `<path d="M${point(start)}A${n(radius)} ${n(radius)} 0 ${end - start > .5 ? 1 : 0} 1 ${point(end)}" fill="none" stroke="${color}" stroke-width="${n(width)}" opacity="${opacity}" ${dash ? `stroke-dasharray="${dash}"` : ''}/>`;
}
function star(size, color, cx = size / 2, cy = size / 2) {
  return Array.from({ length: 8 }, (_, index) => rect(cx, cy, size, Math.max(size * .035, 1.1), index * 22.5, color)).join('') + circle(cx, cy, size * .075, colors.paper, 1, `stroke="${color}" stroke-width="${n(Math.max(1, size * .035))}"`);
}
export function bauhausStar() {
  return `<svg class="brand-star" viewBox="0 0 22 22" aria-hidden="true">${star(20, colors.blue, 11, 11)}</svg>`;
}
function construction(w, h) {
  const m = Math.min(w, h);
  return circle(.5 * w, .52 * h, .37 * m, 'none', 1, `stroke="${colors.ink}" stroke-opacity=".18" stroke-width="1"`) + line(.08 * w, .66 * h, .92 * w, .66 * h, colors.ink, 1, .16, '2 6') + line(.51 * w, .12 * h, .51 * w, .9 * h, colors.ink, 1, .16, '2 6');
}
function skyline(w, h) {
  const c = colors, m = Math.min(w, h), x = .44 * w, y = .5 * h, r = .34 * m;
  const angle = -46 * Math.PI / 180, dx = Math.cos(angle), dy = Math.sin(angle), px = -dy, py = dx, reach = Math.hypot(w, h);
  let art = construction(w, h);
  art += rect(.79*w, .33*h, .30*w, .55*h, -18, c.red, .16);
  art += rect(.72*w, .29*h, .26*w, .52*h, -18, c.red, .92);
  art += rect(.585*w, .635*h, .12*m, .12*m, -38, c.green, .85);
  art += rect(.63*w, .76*h, .36*w, .30*h, -30, c.blueDeep, .9);
  art += rect(.60*w, .73*h, .34*w, .28*h, -30, c.blue, .28);
  art += rect(.79*w, .84*h, .28*w, .26*h, -22, c.yellow, .92);
  const fan = [[c.ink,.7,.58,'',false],[c.red,.8,.46,'',true],[c.blue,.7,.66,'2 6',false],[c.yellow,.9,.38,'',false],[c.green,.65,.31,'',true],[c.ink,.4,.72,'2 6',false],[c.coral,.75,.51,'',false]];
  fan.forEach(([color, opacity, length, dash, node], i) => {
    const gap = Math.max(7, m * .032), sx = .05*w + i*px*gap, sy = .97*h + i*py*gap, ex = sx + dx*reach*length, ey = sy + dy*reach*length;
    art += line(sx, sy, ex, ey, color, 1.3, opacity, dash);
    if (node) art += circle(ex, ey, 2, color, opacity);
  });
  [[.70,.34,.97,.34,c.ink,.30,''],[.72,.42,.99,.42,c.ink,.20,'1 4'],[.68,.58,.96,.58,c.blue,.35,''],[.71,.66,.98,.66,c.ink,.22,''],[.86,.30,.86,.72,c.ink,.22,''],[.935,.38,.935,.80,c.ink,.16,'2 5']].forEach(([x1,y1,x2,y2,color,opacity,dash]) => { art += line(x1*w,y1*h,x2*w,y2*h,color,1.2,opacity,dash); });
  [[.97,.34],[.96,.58],[.86,.72]].forEach(([a,b]) => { art += circle(a*w,b*h,1.75,c.ink,.35); });
  const orbit = r * 1.38, node = Math.max(8, m * .062), theta = .82 * Math.PI;
  art += arc(x,y,orbit,.5,.8,c.yellow,Math.max(1.6,m*.009));
  art += arc(x,y,orbit,.8,.9,c.yellow,Math.max(1.3,m*.007),.5,'2 5');
  art += arc(x,y,r*1.07,.53,.71,c.ink,Math.max(3,m*.016));
  art += circle(x+Math.cos(theta)*orbit,y-Math.sin(theta)*orbit,node/2,c.yellow);
  art += circle(x+Math.cos(theta+.11)*orbit,y-Math.sin(theta+.11)*orbit,node*.225,c.yellow,.55);
  art += circle(x,y,r,c.ink,1,'class="anchor-disc"');
  const thickness = Math.max(7,m*.055), length = reach*1.04;
  [[-1.6,.8,c.ink,.12,1],[1.75,.65,c.ink,.08,1],[0,1,c.ink,.96,1],[.62,.2,c.paper,.95,.98]].forEach(([offset,weight,color,opacity,len]) => { art += rect(.47*w+px*offset*thickness,.47*h+py*offset*thickness,length*len,Math.max(1.5,thickness*weight),-46,color,opacity); });
  const satellite = Math.max(8,m*.075);
  art += circle(.655*w,.115*h,satellite*.75,'none',1,`stroke="${c.red}" stroke-opacity=".25" stroke-width="1.5"`);
  art += circle(.63*w,.10*h,satellite*.475,c.red);
  art += circle(.87*w,.46*h,satellite*.45,c.green);
  art += circle(.115*w,.90*h,satellite*.5,c.blue);
  return art;
}
function crew(w,h) {
  const c = colors;
  let art = construction(w,h);
  Array.from({length:4},(_,i) => i*Math.PI/2-Math.PI/4).forEach((angle,i) => { art += line(.5*w,.51*h,.5*w+Math.cos(angle)*.27*w,.51*h+Math.sin(angle)*.27*h,i%2 ? c.red:c.blue,Math.max(4,w*.018)); });
  art += circle(.5*w,.51*h,.155*w,c.yellow,1,`stroke="${c.ink}" stroke-width="${n(Math.max(4,w*.018))}"`);
  art += star(.18*w,c.paper,.5*w,.51*h);
  art += circle(.24*w,.25*h,.075*w,c.blue);
  art += rect(.76*w,.25*h,.15*w,.15*w,0,c.red);
  art += `<path d="M${n(.25*w)} ${n(.685*h)}L${n(.17*w)} ${n(.835*h)}H${n(.33*w)}Z" fill="${c.yellow}"/>`;
  art += rect(.76*w,.76*h,.12*w,.12*w,45,c.green);
  return art;
}
function score(w,h) {
  const c = colors, gap=.035*w, bar=(.64*w-gap*4)/5, baseline=.93*h;
  let art = construction(w,h) + `<g transform="rotate(-10 ${n(.25*w)} ${n(.68*h)})">${arc(.25*w,.68*h,.335*w,.50,.76,c.blue,Math.max(18,w*.072))}</g>`;
  [.37,.53,.70,.86,.61].forEach((height,i) => { art += rect(.28*w+bar/2+i*(bar+gap),baseline-height*h/2,bar,height*h,0,[c.blue,c.red,c.ink,c.blue,c.green][i]); });
  art += circle(.35*w,.34*h,.125*w,c.yellow);
  art += rect(.59*w,.67*h,.68*w,Math.max(8,h*.052),0,c.red);
  art += star(.13*Math.min(w,h),c.blue,.27*w,.18*h);
  return art;
}
export function bauhausArt(kind = 'home', height = 248, width = 346) {
  const w = width, h = height;
  let geometry = kind === 'crew' ? crew(w,h) : kind === 'score' ? score(w,h) : skyline(w,h);
  if (kind === 'celebration') {
    geometry = `<g transform="translate(${n(w*.06)} ${n(h*.06)}) scale(.88)">${geometry}</g>`;
    geometry += Array.from({length:8},(_,i) => rect(w*(.12+i*.105),h*(.12+(i%3)*.08),Math.max(5,w*.018),Math.max(12,h*.055),i*24,[colors.red,colors.blue,colors.yellow,colors.green][i%4])).join('');
  }
  return `<div class="bauhaus-art art-${kind}" style="--art-height:${height}px" data-testid="bauhaus-art-${kind}" aria-hidden="true"><svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="xMidYMid meet">${geometry}</svg></div>`;
}
