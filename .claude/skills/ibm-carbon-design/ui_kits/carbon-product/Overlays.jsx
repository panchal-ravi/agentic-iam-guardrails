/* global React, Icon, Button */
const { useState: useStateModal } = React;

function Modal({ open, title, subtitle, children, primaryLabel = 'Save', secondaryLabel = 'Cancel', onClose, onPrimary, danger }) {
  if (!open) return null;
  return (
    <div style={{
      position: 'fixed', inset: 0, background: 'rgba(22,22,22,0.5)',
      display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100,
    }} onClick={onClose}>
      <div onClick={e => e.stopPropagation()} style={{
        width: 560, background: '#fff', display: 'flex', flexDirection: 'column',
        boxShadow: '0 2px 6px rgba(0,0,0,0.2)',
      }}>
        <div style={{ padding: '16px 64px 16px 16px', display: 'flex', flexDirection: 'column', gap: 4, position: 'relative' }}>
          {subtitle && <div style={{ fontSize: 12, color: '#525252', letterSpacing: 0.32 }}>{subtitle}</div>}
          <h2 style={{ margin: 0, fontSize: 20, fontWeight: 400, lineHeight: '28px' }}>{title}</h2>
          <button onClick={onClose} style={{ position: 'absolute', right: 0, top: 0, width: 48, height: 48, background: 'transparent', border: 'none', cursor: 'pointer' }}>
            <Icon name="close" size={20}/>
          </button>
        </div>
        <div style={{ padding: '0 16px 32px', flex: 1 }}>{children}</div>
        <div style={{ display: 'flex', borderTop: 'none' }}>
          <button onClick={onClose} style={modalBtn('secondary')}>{secondaryLabel}</button>
          <button onClick={onPrimary} style={modalBtn(danger ? 'danger' : 'primary')}>{primaryLabel}</button>
        </div>
      </div>
    </div>
  );
}
const modalBtn = (kind) => ({
  flex: 1, height: 64, padding: '0 16px', border: 'none', cursor: 'pointer',
  fontSize: 14, letterSpacing: 0.16, color: '#fff', textAlign: 'left',
  background: kind === 'primary' ? '#0f62fe' : kind === 'danger' ? '#da1e28' : '#393939',
});

function Breadcrumb({ items }) {
  return (
    <nav style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 14 }}>
      {items.map((it, i) => (
        <React.Fragment key={i}>
          <a href="#" style={{ color: i === items.length - 1 ? '#161616' : '#525252', textDecoration: i === items.length - 1 ? 'none' : 'underline' }}>{it}</a>
          {i < items.length - 1 && <span style={{ color: '#a8a8a8' }}>/</span>}
        </React.Fragment>
      ))}
    </nav>
  );
}

function Toast({ kind = 'success', title, body, onClose }) {
  const colors = {
    success: { bar: '#24a148', bg: '#defbe6', icon: 'checkmark--filled' },
    error:   { bar: '#da1e28', bg: '#fff1f1', icon: 'warning' },
    warning: { bar: '#f1c21b', bg: '#fcf4d6', icon: 'warning--alt' },
    info:    { bar: '#0043ce', bg: '#edf5ff', icon: 'information' },
  };
  const c = colors[kind];
  return (
    <div style={{
      display: 'flex', alignItems: 'flex-start', padding: '14px 16px',
      borderLeft: `3px solid ${c.bar}`, background: c.bg, minWidth: 320, gap: 12,
      boxShadow: '0 2px 6px rgba(0,0,0,0.15)',
    }}>
      <Icon name={c.icon} size={20} color={c.bar} />
      <div style={{ flex: 1 }}>
        <div style={{ fontWeight: 600, fontSize: 14 }}>{title}</div>
        {body && <div style={{ fontSize: 14, color: '#393939', marginTop: 2 }}>{body}</div>}
      </div>
      {onClose && (
        <button onClick={onClose} style={{ background: 'transparent', border: 'none', cursor: 'pointer' }}>
          <Icon name="close" size={16}/>
        </button>
      )}
    </div>
  );
}

Object.assign(window, { Modal, Breadcrumb, Toast });
