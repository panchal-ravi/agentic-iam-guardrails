/* global React */
const { useState } = React;

const ICON = (name) => `../../assets/icons/${name}.svg`;

function Shell({ children, active = 'home', onNav }) {
  const items = [
    { id: 'home', label: 'Home', icon: 'home' },
    { id: 'projects', label: 'Projects', icon: 'folder' },
    { id: 'prompts', label: 'Prompt Lab', icon: 'document' },
    { id: 'models', label: 'Foundation models', icon: 'api' },
    { id: 'tuning', label: 'Tuning Studio', icon: 'chart--line' },
    { id: 'data', label: 'Data', icon: 'data-base' },
    { id: 'governance', label: 'Governance', icon: 'view' },
  ];
  return (
    <div style={{ minHeight: '100vh', background: '#fff', color: '#161616' }}>
      <header style={{
        height: 48, background: '#161616', color: '#f4f4f4',
        display: 'flex', alignItems: 'center', position: 'sticky', top: 0, zIndex: 10,
        borderBottom: '1px solid #393939',
      }}>
        <button style={{ width: 48, height: 48, background: 'transparent', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <img src={ICON('menu')} width="20" height="20" style={{ filter: 'invert(1)' }}/>
        </button>
        <div style={{ padding: '0 32px 0 8px', borderRight: '1px solid #393939', height: '100%', display: 'flex', alignItems: 'center', gap: 8 }}>
          <strong style={{ fontSize: 14, fontWeight: 600 }}>IBM</strong>
          <span style={{ fontSize: 14 }}>watsonx</span>
        </div>
        <nav style={{ display: 'flex', height: '100%' }}>
          {['Build', 'Tune', 'Deploy', 'Govern'].map((l, i) => (
            <a key={l} href="#" style={{
              padding: '0 16px', display: 'inline-flex', alignItems: 'center', color: '#f4f4f4',
              fontSize: 14, textDecoration: 'none', background: i === 0 ? '#262626' : 'transparent',
            }}>{l}</a>
          ))}
        </nav>
        <div style={{ marginLeft: 'auto', display: 'flex' }}>
          {['search', 'notification', 'help', 'user--avatar'].map(n => (
            <button key={n} style={{ width: 48, height: 48, background: 'transparent', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <img src={ICON(n)} width="20" height="20" style={{ filter: 'invert(1)' }}/>
            </button>
          ))}
        </div>
      </header>

      <div style={{ display: 'flex' }}>
        <aside style={{ width: 256, background: '#f4f4f4', borderRight: '1px solid #e0e0e0', height: 'calc(100vh - 48px)', position: 'sticky', top: 48, paddingTop: 8 }}>
          {items.map(it => {
            const isActive = it.id === active;
            return (
              <button key={it.id} onClick={() => onNav(it.id)} style={{
                width: '100%', height: 32, padding: '0 16px', background: isActive ? '#e0e0e0' : 'transparent',
                border: 'none', borderLeft: `3px solid ${isActive ? '#0f62fe' : 'transparent'}`,
                textAlign: 'left', font: 'inherit', fontSize: 14, color: '#161616',
                cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 10, fontWeight: isActive ? 600 : 400,
              }}>
                <img src={ICON(it.icon)} width="16" height="16"/>
                {it.label}
              </button>
            );
          })}
        </aside>

        <main style={{ flex: 1, padding: '32px 48px 64px', background: '#f4f4f4', minHeight: 'calc(100vh - 48px)' }}>
          {children}
        </main>
      </div>
    </div>
  );
}

function HomePage({ go }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 32 }}>
      <div>
        <div style={{ fontSize: 14, color: '#525252' }}><a href="#" style={{ color: '#525252' }}>watsonx</a> / Home</div>
        <h1 style={{ margin: '16px 0 4px', fontSize: 42, fontWeight: 300, lineHeight: '50px', letterSpacing: '-0.5px' }}>Welcome to watsonx</h1>
        <p style={{ margin: 0, fontSize: 16, color: '#525252', lineHeight: '24px', maxWidth: 720 }}>
          The enterprise-ready AI and data platform. Build, tune, and deploy foundation models — with governance built in.
        </p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 2, background: '#e0e0e0' }}>
        {[
          { k: 'WATSONX.AI', t: 'Open a project', d: 'Start with Prompt Lab or Tuning Studio to iterate on a foundation model.', cta: 'New project', to: 'projects' },
          { k: 'WATSONX.DATA', t: 'Query your data', d: 'Open lakehouse. Query across S3, Cloud Object Storage, and Db2 without moving data.', cta: 'Open data explorer', to: 'data' },
          { k: 'WATSONX.GOVERNANCE', t: 'Monitor AI models', d: 'Track drift, bias, and regulatory risk across every deployed model.', cta: 'Open governance', to: 'governance' },
        ].map(c => (
          <div key={c.k} style={{ background: '#fff', padding: 24, display: 'flex', flexDirection: 'column', gap: 12, minHeight: 200 }}>
            <div style={{ fontFamily: 'var(--cds-font-mono)', fontSize: 11, color: '#6f6f6f', letterSpacing: 0.32, textTransform: 'uppercase' }}>{c.k}</div>
            <h3 style={{ margin: 0, fontSize: 20, lineHeight: '28px', fontWeight: 400 }}>{c.t}</h3>
            <p style={{ margin: 0, fontSize: 14, color: '#525252', lineHeight: '20px' }}>{c.d}</p>
            <button onClick={() => go(c.to)} style={{
              marginTop: 'auto', alignSelf: 'flex-start',
              height: 40, padding: '0 64px 0 16px', background: 'transparent', color: '#0f62fe', border: 'none',
              cursor: 'pointer', fontSize: 14, position: 'relative',
            }}>{c.cta}<span style={{ position: 'absolute', right: 16, top: '50%', transform: 'translateY(-50%)' }}>→</span></button>
          </div>
        ))}
      </div>

      <div>
        <h2 style={{ margin: '0 0 16px', fontSize: 20, fontWeight: 400 }}>Foundation models</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 2, background: '#e0e0e0' }}>
          {[
            ['granite-3-8b-instruct', 'IBM', '8B', 'Instruction-tuned general model from IBM Granite family.'],
            ['llama-3-70b-instruct', 'Meta', '70B', 'Large open model for complex reasoning.'],
            ['mixtral-8x7b-instruct', 'Mistral AI', '47B', 'Sparse MoE for cost-efficient throughput.'],
            ['slate-125m-english-rtrvr', 'IBM', '125M', 'Embedding model for retrieval and RAG.'],
          ].map(([name, vendor, size, desc]) => (
            <div key={name} style={{ background: '#fff', padding: 20, display: 'flex', flexDirection: 'column', gap: 8, minHeight: 170 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, height: 20, padding: '0 6px', background: '#d0e2ff', color: '#002d9c', fontSize: 11, borderRadius: 12 }}>{vendor}</span>
                <span style={{ fontFamily: 'var(--cds-font-mono)', fontSize: 11, color: '#6f6f6f' }}>{size}</span>
              </div>
              <div style={{ fontFamily: 'var(--cds-font-mono)', fontSize: 13, fontWeight: 600, color: '#161616' }}>{name}</div>
              <div style={{ fontSize: 14, color: '#525252', lineHeight: '20px' }}>{desc}</div>
              <button style={{ marginTop: 'auto', alignSelf: 'flex-start', height: 32, padding: '0 48px 0 12px', background: 'transparent', color: '#0f62fe', border: '1px solid #0f62fe', cursor: 'pointer', fontSize: 13, position: 'relative' }}>
                Try in Prompt Lab
                <span style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)' }}>→</span>
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function PromptLab() {
  const [prompt, setPrompt] = useState('Summarize the following customer feedback into 3 bullets, highlighting the most actionable complaints:\n\n---\n\n"I love the new dashboard but the API keys page is confusing. Also, pricing jumped without warning. Support took 4 days to respond."');
  const [output, setOutput] = useState('• The new dashboard is well-received.\n• API keys page UX needs review — users report confusion.\n• Pricing changes should be announced in advance; SLA on support response time is currently 4 days and should be tightened.');
  const [running, setRunning] = useState(false);
  const [model, setModel] = useState('granite-3-8b-instruct');

  const run = () => {
    setRunning(true);
    setTimeout(() => { setRunning(false); }, 900);
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div>
        <div style={{ fontSize: 14, color: '#525252' }}><a href="#" style={{ color: '#525252' }}>watsonx</a> / Projects / customer-feedback-analysis / Prompt Lab</div>
        <h1 style={{ margin: '12px 0 4px', fontSize: 28, fontWeight: 400, lineHeight: '36px' }}>Prompt Lab</h1>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 320px', gap: 16 }}>
        <div style={{ background: '#fff', border: '1px solid #e0e0e0', display: 'flex', flexDirection: 'column' }}>
          <div style={{ height: 48, borderBottom: '1px solid #e0e0e0', display: 'flex', alignItems: 'center', padding: '0 16px', gap: 16 }}>
            {['Freeform', 'Structured', 'Chat'].map((t, i) => (
              <button key={t} style={{
                height: 47, padding: '0 8px', background: 'transparent', border: 'none', cursor: 'pointer',
                fontSize: 14, color: i === 0 ? '#161616' : '#525252', borderBottom: i === 0 ? '2px solid #0f62fe' : '2px solid transparent', fontWeight: i === 0 ? 600 : 400,
              }}>{t}</button>
            ))}
            <div style={{ marginLeft: 'auto', display: 'flex', gap: 4 }}>
              <button style={iconBtn}><img src={ICON('view')} width="16" height="16"/></button>
              <button style={iconBtn}><img src={ICON('copy')} width="16" height="16"/></button>
              <button style={iconBtn}><img src={ICON('overflow-menu--vertical')} width="16" height="16"/></button>
            </div>
          </div>
          <textarea
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
            style={{
              border: 'none', outline: 'none', resize: 'none', padding: 16, fontSize: 14,
              fontFamily: 'var(--cds-font-mono)', lineHeight: '20px', color: '#161616',
              minHeight: 240, borderBottom: '1px solid #e0e0e0',
            }}
          />
          <div style={{ padding: 16, background: '#f4f4f4', display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ fontFamily: 'var(--cds-font-mono)', fontSize: 11, color: '#6f6f6f', letterSpacing: 0.32, textTransform: 'uppercase' }}>Model response</div>
            <pre style={{ margin: 0, fontFamily: 'var(--cds-font-sans)', fontSize: 14, lineHeight: '20px', whiteSpace: 'pre-wrap', color: '#161616' }}>{running ? '…' : output}</pre>
          </div>
          <div style={{ padding: 16, display: 'flex', alignItems: 'center', gap: 12, borderTop: '1px solid #e0e0e0' }}>
            <span style={{ fontSize: 12, color: '#6f6f6f', fontFamily: 'var(--cds-font-mono)' }}>{prompt.length} chars · 128 tokens in · 52 out</span>
            <button style={{ marginLeft: 'auto', height: 40, padding: '0 16px', background: 'transparent', color: '#0f62fe', border: '1px solid #0f62fe', cursor: 'pointer', fontSize: 14 }}>Save as asset</button>
            <button onClick={run} style={{ height: 40, padding: '0 64px 0 16px', background: '#0f62fe', color: '#fff', border: 'none', cursor: 'pointer', fontSize: 14, position: 'relative' }}>
              {running ? 'Running…' : 'Run'}
              <span style={{ position: 'absolute', right: 16, top: '50%', transform: 'translateY(-50%)' }}>→</span>
            </button>
          </div>
        </div>

        <aside style={{ background: '#fff', border: '1px solid #e0e0e0', padding: 20, display: 'flex', flexDirection: 'column', gap: 20 }}>
          <div>
            <div style={{ fontSize: 12, color: '#525252', letterSpacing: 0.32, marginBottom: 6 }}>Model</div>
            <select value={model} onChange={(e) => setModel(e.target.value)} style={{
              width: '100%', height: 40, padding: '0 16px', background: '#f4f4f4', border: 'none',
              borderBottom: '1px solid #8d8d8d', fontSize: 14, fontFamily: 'inherit',
            }}>
              <option>granite-3-8b-instruct</option>
              <option>llama-3-70b-instruct</option>
              <option>mixtral-8x7b-instruct</option>
            </select>
          </div>
          <Param label="Decoding" value="Greedy · deterministic"/>
          <Param label="Max new tokens" slider={200} max={4096}/>
          <Param label="Temperature" slider={0.7} max={2} step={0.1}/>
          <Param label="Top P" slider={1} max={1} step={0.05}/>
          <Param label="Repetition penalty" slider={1} max={2} step={0.05}/>
          <div>
            <div style={{ fontSize: 12, color: '#525252', letterSpacing: 0.32, marginBottom: 6 }}>Stop sequences</div>
            <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
              <span style={{ fontSize: 12, height: 24, display: 'inline-flex', alignItems: 'center', padding: '0 8px', background: '#e0e0e0', borderRadius: 16 }}>\n\n ×</span>
              <span style={{ fontSize: 12, height: 24, display: 'inline-flex', alignItems: 'center', padding: '0 8px', background: '#e0e0e0', borderRadius: 16 }}>---  ×</span>
            </div>
          </div>
        </aside>
      </div>
    </div>
  );
}

function Param({ label, value, slider, max, step }) {
  const [v, setV] = useState(slider);
  return (
    <div>
      <div style={{ display: 'flex', marginBottom: 6 }}>
        <span style={{ fontSize: 12, color: '#525252', letterSpacing: 0.32 }}>{label}</span>
        <span style={{ marginLeft: 'auto', fontFamily: 'var(--cds-font-mono)', fontSize: 12, color: '#161616' }}>{slider !== undefined ? v : value}</span>
      </div>
      {slider !== undefined ? (
        <input type="range" min="0" max={max} step={step || 1} value={v} onChange={(e) => setV(parseFloat(e.target.value))} style={{ width: '100%', accentColor: '#0f62fe' }}/>
      ) : null}
    </div>
  );
}

const iconBtn = {
  width: 32, height: 32, background: 'transparent', border: 'none', cursor: 'pointer',
  display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
};

function Projects() {
  const rows = [
    { id: 1, name: 'customer-feedback-analysis', assets: 12, model: 'granite-3-8b-instruct', updated: '2026-04-17', status: 'Active' },
    { id: 2, name: 'contract-summarization', assets: 8, model: 'llama-3-70b-instruct', updated: '2026-04-15', status: 'Active' },
    { id: 3, name: 'code-assist-pilot', assets: 34, model: 'granite-code-20b', updated: '2026-04-12', status: 'Active' },
    { id: 4, name: 'retail-chatbot-v2', assets: 22, model: 'mixtral-8x7b-instruct', updated: '2026-04-02', status: 'Archived' },
  ];
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div>
        <div style={{ fontSize: 14, color: '#525252' }}>watsonx / Projects</div>
        <div style={{ display: 'flex', alignItems: 'flex-end', marginTop: 12 }}>
          <h1 style={{ margin: 0, fontSize: 28, fontWeight: 400 }}>Projects</h1>
          <div style={{ marginLeft: 'auto', display: 'flex', gap: 1 }}>
            <button style={{ height: 40, padding: '0 16px', background: '#393939', color: '#fff', border: 'none', cursor: 'pointer', fontSize: 14 }}>Import</button>
            <button style={{ height: 40, padding: '0 64px 0 16px', background: '#0f62fe', color: '#fff', border: 'none', cursor: 'pointer', fontSize: 14, position: 'relative' }}>
              New project
              <span style={{ position: 'absolute', right: 16, top: '50%', transform: 'translateY(-50%)' }}>+</span>
            </button>
          </div>
        </div>
      </div>

      <div style={{ background: '#fff', border: '1px solid #e0e0e0' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 14 }}>
          <thead>
            <tr style={{ background: '#e0e0e0' }}>
              <th style={thSt}>Name</th>
              <th style={thSt}>Assets</th>
              <th style={thSt}>Primary model</th>
              <th style={thSt}>Last updated</th>
              <th style={thSt}>Status</th>
              <th style={{...thSt, width: 48}}></th>
            </tr>
          </thead>
          <tbody>
            {rows.map(r => (
              <tr key={r.id} style={{ borderBottom: '1px solid #e0e0e0' }}>
                <td style={{...tdSt, fontFamily: 'var(--cds-font-mono)', color: '#0f62fe'}}>{r.name}</td>
                <td style={tdSt}>{r.assets}</td>
                <td style={{...tdSt, fontFamily: 'var(--cds-font-mono)', fontSize: 12}}>{r.model}</td>
                <td style={tdSt}>{r.updated}</td>
                <td style={tdSt}>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, height: 20, padding: '0 6px',
                    background: r.status === 'Active' ? '#a7f0ba' : '#e0e0e0',
                    color: r.status === 'Active' ? '#044317' : '#393939', fontSize: 11, borderRadius: 12 }}>
                    {r.status}
                  </span>
                </td>
                <td style={tdSt}><img src={ICON('overflow-menu--vertical')} width="16" height="16"/></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

const thSt = { height: 48, padding: '0 16px', textAlign: 'left', fontSize: 14, fontWeight: 600, color: '#161616' };
const tdSt = { height: 48, padding: '0 16px', color: '#525252' };

function StubPage({ title }) {
  return (
    <div>
      <div style={{ fontSize: 14, color: '#525252' }}>watsonx / {title}</div>
      <h1 style={{ margin: '16px 0 4px', fontSize: 28, fontWeight: 400 }}>{title}</h1>
      <p style={{ fontSize: 16, color: '#525252' }}>This surface is stubbed. Home, Projects, and Prompt Lab have full interactive flows.</p>
    </div>
  );
}

function App() {
  const [active, setActive] = useState('home');
  return (
    <Shell active={active} onNav={setActive}>
      {active === 'home' && <HomePage go={setActive} />}
      {active === 'projects' && <Projects/>}
      {active === 'prompts' && <PromptLab/>}
      {!['home','projects','prompts'].includes(active) && <StubPage title={{models:'Foundation models', tuning:'Tuning Studio', data:'Data', governance:'Governance'}[active]}/>}
    </Shell>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
