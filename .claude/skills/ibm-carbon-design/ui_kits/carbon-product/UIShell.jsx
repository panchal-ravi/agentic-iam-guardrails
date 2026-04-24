/* global React, Icon */
const { useState: useStateShell } = React;

function UIShellHeader({ productName = 'IBM Cloud', user = 'Sam Lee', onMenu }) {
  return (
    <header style={{
      height: 48, background: '#161616', color: '#f4f4f4',
      display: 'flex', alignItems: 'center', borderBottom: '1px solid #393939',
      position: 'sticky', top: 0, zIndex: 10,
    }}>
      <button onClick={onMenu} aria-label="Open menu" style={{
        width: 48, height: 48, background: 'transparent', border: 'none',
        display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
      }}>
        <Icon name="menu" size={20} color="#f4f4f4" />
      </button>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, paddingLeft: 8, paddingRight: 32, borderRight: '1px solid #393939', height: '100%', alignItems: 'center' }}>
        <span style={{ fontWeight: 600, fontSize: 14 }}>IBM</span>
        <span style={{ fontSize: 14, opacity: 0.85 }}>{productName}</span>
      </div>
      <nav style={{ display: 'flex', height: '100%' }}>
        {['Catalog', 'Docs', 'Support', 'Manage'].map((n, i) => (
          <a key={n} href="#" style={{
            padding: '0 16px', display: 'inline-flex', alignItems: 'center',
            color: '#f4f4f4', fontSize: 14, textDecoration: 'none',
            borderLeft: '2px solid transparent',
            borderBottom: i === 0 ? 'none' : 'none',
            background: i === 0 ? '#262626' : 'transparent',
            letterSpacing: 0.16,
          }}>{n}</a>
        ))}
      </nav>
      <div style={{ marginLeft: 'auto', display: 'flex', height: '100%' }}>
        {['search', 'notification', 'user--avatar'].map((n) => (
          <button key={n} style={{ width: 48, height: 48, background: 'transparent', border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <Icon name={n} size={20} color="#f4f4f4" />
          </button>
        ))}
      </div>
    </header>
  );
}

function UIShellSideNav({ items, active, onSelect }) {
  return (
    <aside style={{
      width: 256, background: '#f4f4f4', borderRight: '1px solid #e0e0e0',
      display: 'flex', flexDirection: 'column', paddingTop: 8,
      height: 'calc(100vh - 48px)', position: 'sticky', top: 48,
    }}>
      {items.map((it) => {
        const isActive = it.id === active;
        return (
          <button
            key={it.id} onClick={() => onSelect(it.id)}
            style={{
              height: 32, padding: '0 16px', background: isActive ? '#e0e0e0' : 'transparent',
              border: 'none', borderLeft: `3px solid ${isActive ? '#0f62fe' : 'transparent'}`,
              textAlign: 'left', font: 'inherit', fontSize: 14, color: '#161616',
              cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 10,
              fontWeight: isActive ? 600 : 400,
            }}
          >
            <Icon name={it.icon} size={16} color="#161616" />
            {it.label}
          </button>
        );
      })}
    </aside>
  );
}

Object.assign(window, { UIShellHeader, UIShellSideNav });
