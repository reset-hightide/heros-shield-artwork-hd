// Opening: PRESS START -> the Song of Time carved into a metal plate, each note appearing as the game plays it
// (original PRESS START sound, then the Song of Time track in sync), then "Dawn of the First Day". Skippable; once per visit.
(function () {
  const root = document.getElementById('intro');
  if (!root) return;
  const pt = (document.documentElement.lang || 'pt').startsWith('pt');
  const $ = (s) => root.querySelector(s);
  const svg = $('#intro-svg');
  const NS = 'http://www.w3.org/2000/svg';
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function done() {
    root.classList.add('intro-out');
    document.body.classList.remove('intro-lock');
    setTimeout(() => { root.hidden = true; }, 900);
    try { sessionStorage.setItem('introSeen', '1'); } catch (e) {}
  }
  if (location.hash === '#nointro') { root.hidden = true; return; }
  try { if (sessionStorage.getItem('introSeen') && location.hash !== '#intro-test') { root.hidden = true; return; } } catch (e) {}
  document.body.classList.add('intro-lock');
  $('#intro-skip').addEventListener('click', () => { stopAudio(); done(); });

  let song = null, cfg = null;
  Promise.all([
    fetch('assets/intro/song.json').then((r) => r.json()),
    fetch('assets/intro/timing.json').then((r) => r.json()),
  ]).then(([s, c]) => {
    song = s; cfg = c; build();
    const get = (u) => fetch(u).then((r) => r.arrayBuffer()).catch(() => null);
    bytes = Promise.all([get(cfg.pressStart), get(cfg.song)]).then(([press, song]) => ({ press, song }));
  }).catch(() => done());
  // until song/timing load, PRESS START waits (start() checks cfg)

  function el(tag, attrs, parent) {
    const e = document.createElementNS(NS, tag);
    for (const k in attrs) e.setAttribute(k, attrs[k]);
    (parent || svg).appendChild(e);
    return e;
  }

  let lines = [], clef, notes = [];
  function build() {
    svg.setAttribute('viewBox', song.view.join(' '));
    const g = el('g', { class: 'carve' });
    song.lines.forEach((d, i) => {
      const p = el('path', { d, class: 'groove line' }, g);
      p.style.setProperty('--i', i);
      lines.push(p);
    });
    clef = el('path', { d: song.clef, class: 'groove clef' }, g);
    song.notes.forEach((n) => {
      const ng = el('g', { class: 'note' }, g);
      ng.style.transformOrigin = n.x + 'px ' + n.y + 'px';
      el('path', { d: n.face, class: 'face' }, ng);
      el('path', { d: n.ring, class: 'groove' }, ng);
      el('path', { d: n.sym, class: 'groove' }, ng);
      notes.push(ng);
    });
  }

  // audio: the original PRESS START sound and the Song of Time track; each note is carved when it sounds
  let ctx = null, sources = [];
  const bufs = {};
  let bytes = Promise.resolve({});
  function stopAudio() { sources.forEach((s) => { try { s.stop(); } catch (e) {} }); sources = []; }
  function play(buf, when) {
    const s = ctx.createBufferSource();
    s.buffer = buf; s.connect(ctx.destination); s.start(when);
    sources.push(s);
  }

  $('#intro-start').addEventListener('click', start, { once: true });
  if (location.hash === '#intro-test') { root.classList.add('intro-notrans'); setTimeout(() => $('#intro-start').click(), 600); }   // screenshot hook
  async function start() {
    if (!cfg || !song) { done(); return; }
    root.classList.add('intro-playing');
    // audio never holds the intro up: give decoding a short window, then go on (silently if it isn't ready)
    try {
      ctx = new (window.AudioContext || window.webkitAudioContext)();
      ctx.resume && ctx.resume();
      const decode = bytes.then(async (b) => {
        for (const k of ['press', 'song']) if (b[k]) bufs[k] = await ctx.decodeAudioData(b[k].slice(0));
      });
      await Promise.race([decode, new Promise((res) => setTimeout(res, 1500))]);
    } catch (e) { ctx = null; }
    const now = ctx ? ctx.currentTime + 0.03 : 0;
    if (ctx && bufs.press) play(bufs.press, now);
    const t0 = cfg.pressLen;                           // the plate appears as the PRESS START sound ends
    if (ctx && bufs.song) play(bufs.song, now + t0 / 1000);
    setTimeout(() => {
      root.classList.add('intro-carving');
      lines.forEach((p, i) => setTimeout(() => p.classList.add('in'), reduce ? 0 : i * 70));
      setTimeout(() => clef.classList.add('in'), reduce ? 0 : 260);
      cfg.songOnsets.forEach((ms, i) => setTimeout(() => notes[i] && notes[i].classList.add('in'), ms));
      const end = cfg.songLength;
      setTimeout(() => root.classList.add('intro-dawn'), end - cfg.dawnBeforeEnd);
      setTimeout(done, end + 400);
    }, t0);
  }
})();
