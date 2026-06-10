/* ============================================================================
FOUNDRYMTR THE DISPATCH - collapsible newspaper widget
Fetches news from the FoundryMTR CDN text feed and renders it as articles.
Collapsible: a red tab on the right edge toggles the panel open/closed.

NEWS FILE FORMAT (plain text):
# Headline
@ Byline or date
Body paragraph. Blank line = new paragraph.
---            (article separator; a single em-dash line is also accepted)
# Next headline
...
============================================================================ */

const FOUNDRYMTR_NEWS_URL = 'https://files.foundrymtr.com/news/news.txt'

function fmtrParseNews(text) {
    text = text.replace(/^\uFEFF/, '').replace(/\r\n/g, '\n').replace(/\r/g, '\n')
    const articles = []
    let current = null, paragraphs = [], buffer = []
    const flushP = () => { if (buffer.length) { paragraphs.push(buffer.join(' ').trim()); buffer = [] } }
    const flushA = () => { flushP(); if (current) { current.paragraphs = paragraphs.filter(p => p.length); articles.push(current) } paragraphs = [] }
    for (const raw of text.split('\n')) {
        const line = raw.trim()
        if (line.startsWith('# ')) { flushA(); current = { title: line.slice(2).trim(), byline: '', paragraphs: [] } }
        else if (line === '---' || line === '\u2014') { flushA(); current = null }
        else if (line.startsWith('@ ')) { if (current) current.byline = line.slice(2).trim() }
        else if (line === '') { flushP() }
        else { if (!current) current = { title: '', byline: '', paragraphs: [] }; buffer.push(line) }
    }
    flushA()
    return articles
}

function fmtrEscape(s) {
    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

function fmtrRenderNews(articles) {
    const body = document.getElementById('fmtrNewsBody')
    if (!body) return
    if (!articles || !articles.length) {
        body.innerHTML = '<div id="fmtrNewsError">No bulletins posted.</div>'
        return
    }
    let html = ''
    articles.forEach((a, i) => {
        html += '<div class="fmtr-article">'
        if (a.title) html += '<h3>' + fmtrEscape(a.title) + '</h3>'
        if (a.byline) html += '<p class="byline">' + fmtrEscape(a.byline) + '</p>'
        a.paragraphs.forEach(p => { html += '<p>' + fmtrEscape(p) + '</p>' })
        if (i < articles.length - 1) html += '<hr>'
        html += '</div>'
    })
    body.innerHTML = html
}

function fmtrUpdateDate() {
    const el = document.getElementById('fmtrNewsDate')
    if (el) el.textContent = new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })
}

function fmtrLoadNews() {
    const body = document.getElementById('fmtrNewsBody')
    if (!body) return
    body.innerHTML = '<div id="fmtrNewsLoading">Setting the press...</div>'
    fmtrUpdateDate()
    fetch(FOUNDRYMTR_NEWS_URL + '?t=' + Date.now())
        .then(r => { if (!r.ok) throw new Error('HTTP ' + r.status); return r.text() })
        .then(t => fmtrRenderNews(fmtrParseNews(t)))
        .catch(e => { body.innerHTML = '<div id="fmtrNewsError">Wire down.<br>(' + fmtrEscape(String(e.message || e)) + ')</div>' })
}

function fmtrWireToggle() {
    const tab = document.getElementById('fmtrNewsTab')
    const panel = document.getElementById('fmtrNews')
    const close = document.getElementById('fmtrNewsClose')
    if (!tab || !panel) return
    tab.addEventListener('click', () => {
        panel.classList.toggle('open')
        if (panel.classList.contains('open')) fmtrLoadNews()
    })
    if (close) close.addEventListener('click', () => panel.classList.remove('open'))
}

function fmtrInitNews() {
    fmtrWireToggle()
    fmtrLoadNews()              // preload so it is ready when opened
    setInterval(fmtrLoadNews, 5 * 60 * 1000)
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', fmtrInitNews)
} else {
    fmtrInitNews()
}
