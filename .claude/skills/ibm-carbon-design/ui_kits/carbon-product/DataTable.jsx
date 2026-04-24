/* global React, Icon, Tag, Button */
const { useState: useStateDT } = React;

function DataTable({ columns, rows, title, description, onRowClick }) {
  const [selected, setSelected] = useStateDT(new Set());
  const [sortCol, setSortCol] = useStateDT(null);

  const toggle = (id) => {
    const next = new Set(selected);
    next.has(id) ? next.delete(id) : next.add(id);
    setSelected(next);
  };
  const allChecked = rows.length > 0 && selected.size === rows.length;

  return (
    <div style={{ background: '#fff', border: '1px solid #e0e0e0' }}>
      {/* Toolbar */}
      <div style={{ padding: '16px 16px 16px 16px', display: 'flex', alignItems: 'flex-start', gap: 16, borderBottom: '1px solid #e0e0e0' }}>
        <div style={{ flex: 1 }}>
          <h3 style={{ margin: 0, fontSize: 16, lineHeight: '22px', fontWeight: 600 }}>{title}</h3>
          {description && <div style={{ marginTop: 4, fontSize: 14, color: '#525252' }}>{description}</div>}
        </div>
        <div style={{ display: 'flex', gap: 1 }}>
          <button style={tbBtn}><Icon name="search" size={16}/></button>
          <button style={tbBtn}><Icon name="filter" size={16}/></button>
          <button style={tbBtn}><Icon name="sort-ascending" size={16}/></button>
          <button style={tbBtn}><Icon name="download" size={16}/></button>
          <Button kind="primary" size="md" icon="add">New resource</Button>
        </div>
      </div>

      {/* Selection bar */}
      {selected.size > 0 && (
        <div style={{ padding: '0 16px', height: 48, display: 'flex', alignItems: 'center', gap: 16,
          background: '#0f62fe', color: '#fff', fontSize: 14 }}>
          <span>{selected.size} item{selected.size > 1 ? 's' : ''} selected</span>
          <div style={{ marginLeft: 'auto', display: 'flex', gap: 1 }}>
            <button style={{...tbBtn, color: '#fff'}}><Icon name="copy" size={16} color="#fff"/></button>
            <button style={{...tbBtn, color: '#fff'}}><Icon name="edit" size={16} color="#fff"/></button>
            <button style={{...tbBtn, color: '#fff'}}><Icon name="delete" size={16} color="#fff"/></button>
          </div>
        </div>
      )}

      <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 14 }}>
        <thead>
          <tr style={{ background: '#e0e0e0' }}>
            <th style={{...thStyle, width: 40}}>
              <input type="checkbox" checked={allChecked}
                onChange={() => setSelected(allChecked ? new Set() : new Set(rows.map(r => r.id)))}
                style={{ accentColor: '#0f62fe' }}/>
            </th>
            {columns.map(c => (
              <th key={c.key} style={thStyle} onClick={() => setSortCol(c.key)}>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                  {c.label}
                  {sortCol === c.key && <Icon name="chevron--down" size={12} color="#161616"/>}
                </span>
              </th>
            ))}
            <th style={{...thStyle, width: 48}}></th>
          </tr>
        </thead>
        <tbody>
          {rows.map(row => (
            <tr key={row.id}
              onClick={() => onRowClick && onRowClick(row)}
              style={{ borderBottom: '1px solid #e0e0e0', cursor: onRowClick ? 'pointer' : 'default',
                background: selected.has(row.id) ? '#e0e0e0' : '#fff' }}>
              <td style={tdStyle} onClick={e => e.stopPropagation()}>
                <input type="checkbox" checked={selected.has(row.id)} onChange={() => toggle(row.id)} style={{accentColor: '#0f62fe'}}/>
              </td>
              {columns.map(c => (
                <td key={c.key} style={tdStyle}>
                  {c.render ? c.render(row) : row[c.key]}
                </td>
              ))}
              <td style={tdStyle} onClick={e => e.stopPropagation()}>
                <button style={{...tbBtn, height: 32}}><Icon name="overflow-menu--vertical" size={16}/></button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

const thStyle = {
  height: 48, padding: '0 16px', textAlign: 'left',
  fontSize: 14, fontWeight: 600, color: '#161616',
  cursor: 'pointer', letterSpacing: 0,
};
const tdStyle = { height: 48, padding: '0 16px', color: '#525252' };
const tbBtn = {
  width: 40, height: 48, background: '#e0e0e0', border: 'none',
  display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
  cursor: 'pointer',
};

Object.assign(window, { DataTable });
