/* global React */
const { useState } = React;

function Icon({ name, size = 16, color = 'currentColor' }) {
  // Use <img> with filter for color; simpler and more robust than mask-image.
  const filter = color === '#fff' || color === '#ffffff' || color === '#f4f4f4'
    ? 'invert(1) brightness(2)' : 'none';
  return (
    <img
      src={`../../assets/icons/${name}.svg`}
      aria-hidden="true"
      width={size} height={size}
      style={{ display: 'inline-block', flex: 'none', filter, verticalAlign: 'middle' }}
    />
  );
}

function Button({ kind = 'primary', size = 'md', icon, children, onClick, disabled }) {
  const kinds = {
    primary: { bg: '#0f62fe', fg: '#fff', hover: '#0050e6' },
    secondary: { bg: '#393939', fg: '#fff', hover: '#474747' },
    tertiary: { bg: 'transparent', fg: '#0f62fe', border: '1px solid #0f62fe', hover: '#0f62fe0d' },
    ghost: { bg: 'transparent', fg: '#0f62fe', hover: '#0f62fe0d' },
    danger: { bg: '#da1e28', fg: '#fff', hover: '#b81921' },
  };
  const k = kinds[kind];
  const heights = { sm: 32, md: 40, lg: 48, xl: 64 };
  const [hover, setHover] = useState(false);
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        height: heights[size],
        padding: icon ? '0 16px 0 16px' : '0 16px',
        paddingRight: icon ? 64 : 16,
        background: hover ? k.hover : k.bg,
        color: k.fg,
        border: k.border || 'none',
        borderRadius: 0,
        font: 'inherit',
        fontSize: 14,
        letterSpacing: 0.16,
        cursor: disabled ? 'not-allowed' : 'pointer',
        display: 'inline-flex',
        alignItems: 'center',
        gap: 8,
        position: 'relative',
        opacity: disabled ? 0.35 : 1,
      }}
    >
      {children}
      {icon && (
        <span style={{ marginLeft: 'auto', position: 'absolute', right: 16, top: '50%', transform: 'translateY(-50%)' }}>
          <Icon name={icon} size={16} color={k.fg} />
        </span>
      )}
    </button>
  );
}

function TextInput({ label, helper, error, value, onChange, placeholder }) {
  const [focused, setFocused] = useState(false);
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      {label && <label style={{ fontSize: 12, lineHeight: '16px', letterSpacing: 0.32, color: '#525252' }}>{label}</label>}
      <div style={{ position: 'relative' }}>
        <input
          value={value} onChange={onChange} placeholder={placeholder}
          onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
          style={{
            height: 40, width: '100%', padding: '0 16px', boxSizing: 'border-box',
            background: '#f4f4f4',
            border: 'none',
            borderBottom: `1px solid ${error ? '#da1e28' : '#8d8d8d'}`,
            outline: focused ? '2px solid #0f62fe' : 'none',
            outlineOffset: -2,
            fontSize: 14, fontFamily: 'inherit', color: '#161616',
            borderRadius: 0,
          }}
        />
      </div>
      {error ? <div style={{ fontSize: 12, color: '#da1e28', letterSpacing: 0.32 }}>{error}</div>
             : helper && <div style={{ fontSize: 12, color: '#6f6f6f', letterSpacing: 0.32 }}>{helper}</div>}
    </div>
  );
}

function Tag({ kind = 'gray', children }) {
  const colors = {
    gray: ['#e0e0e0', '#393939'],
    red: ['#ffd7d9', '#750e13'],
    blue: ['#d0e2ff', '#002d9c'],
    green: ['#a7f0ba', '#044317'],
    purple: ['#e8daff', '#491d8b'],
    teal: ['#9ef0f0', '#005d5d'],
    magenta: ['#ffd6e8', '#740937'],
  };
  const [bg, fg] = colors[kind];
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 4,
      height: 24, padding: '0 8px', borderRadius: 16,
      background: bg, color: fg, fontSize: 12, letterSpacing: 0.32,
    }}>{children}</span>
  );
}

function Tile({ children, onClick, selected, style }) {
  const [hover, setHover] = useState(false);
  return (
    <div
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        background: hover ? '#e8e8e8' : '#ffffff',
        padding: 16, minHeight: 96, cursor: onClick ? 'pointer' : 'default',
        outline: selected ? '2px solid #0f62fe' : 'none', outlineOffset: -2,
        position: 'relative', display: 'flex', flexDirection: 'column', gap: 6,
        border: '1px solid #e0e0e0',
        ...style,
      }}
    >{children}</div>
  );
}

Object.assign(window, { Icon, Button, TextInput, Tag, Tile });
