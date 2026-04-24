/* global React, Icon, Button, Tile, Tag, UIShellHeader, UIShellSideNav, DataTable, Modal, Breadcrumb, Toast */
const { useState } = React;

const NAV = [
  { id: 'home', label: 'Dashboard', icon: 'dashboard' },
  { id: 'resources', label: 'Resource list', icon: 'folder' },
  { id: 'databases', label: 'Databases', icon: 'data-base' },
  { id: 'api', label: 'API keys', icon: 'api' },
  { id: 'analytics', label: 'Analytics', icon: 'analytics' },
  { id: 'billing', label: 'Billing', icon: 'chart--line' },
  { id: 'docs', label: 'Documentation', icon: 'document' },
  { id: 'settings', label: 'Settings', icon: 'settings' },
];

const RESOURCES = [
  { id: 1, name: 'prod-api-gateway', type: 'API Gateway', region: 'us-south', status: 'Active', created: '2026-03-12' },
  { id: 2, name: 'analytics-warehouse', type: 'Db2 Warehouse', region: 'us-east', status: 'Active', created: '2026-02-28' },
  { id: 3, name: 'user-events-stream', type: 'Event Streams', region: 'eu-de', status: 'Provisioning', created: '2026-04-10' },
  { id: 4, name: 'legacy-mainframe-bridge', type: 'Integration', region: 'us-south', status: 'Suspended', created: '2025-11-04' },
  { id: 5, name: 'watsonx-inference-01', type: 'watsonx.ai', region: 'us-east', status: 'Active', created: '2026-04-01' },
  { id: 6, name: 'customer-profiles-db', type: 'Cloudant', region: 'eu-gb', status: 'Active', created: '2026-01-17' },
  { id: 7, name: 'staging-object-storage', type: 'COS Bucket', region: 'us-south', status: 'Active', created: '2026-03-22' },
];

const STATUS_TAG = {
  Active: <Tag kind="green">● Active</Tag>,
  Provisioning: <Tag kind="blue">○ Provisioning</Tag>,
  Suspended: <Tag kind="red">● Suspended</Tag>,
};

function Dashboard({ setActive, onCreate }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 32 }}>
      <div>
        <Breadcrumb items={['IBM Cloud', 'Dashboard']} />
        <h1 style={{ margin: '16px 0 4px', fontSize: 28, fontWeight: 400, lineHeight: '36px' }}>Welcome back, Sam</h1>
        <p style={{ margin: 0, fontSize: 16, color: '#525252', lineHeight: '24px' }}>
          7 resources running across 3 regions. Your monthly usage is at 42% of the included plan.
        </p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 2, background: '#e0e0e0' }}>
        {[
          { kicker: 'COMPUTE', value: '7', label: 'Active resources', delta: '+2 this month' },
          { kicker: 'TRAFFIC', value: '1.42M', label: 'API calls (30d)', delta: '+18% MoM' },
          { kicker: 'STORAGE', value: '842 GB', label: 'Object storage used', delta: '+4% MoM' },
          { kicker: 'COST', value: '$2,184', label: 'Projected this month', delta: 'On track' },
        ].map((k) => (
          <Tile key={k.kicker} style={{ border: 'none' }}>
            <div style={{ fontFamily: 'var(--cds-font-mono)', fontSize: 11, letterSpacing: 0.32, color: '#6f6f6f' }}>{k.kicker}</div>
            <div style={{ fontSize: 32, lineHeight: '40px', fontWeight: 300 }}>{k.value}</div>
            <div style={{ fontSize: 14, color: '#525252' }}>{k.label}</div>
            <div style={{ fontSize: 12, color: '#0043ce', marginTop: 'auto' }}>{k.delta}</div>
          </Tile>
        ))}
      </div>

      <div>
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: 16 }}>
          <h2 style={{ margin: 0, fontSize: 20, fontWeight: 400 }}>Your resources</h2>
          <div style={{ marginLeft: 'auto' }}>
            <Button kind="tertiary" size="sm" icon="arrow--right" onClick={() => setActive('resources')}>View all</Button>
          </div>
        </div>

        <DataTable
          title="Recently updated"
          description="Resources provisioned or modified in the last 14 days."
          columns={[
            { key: 'name', label: 'Name' },
            { key: 'type', label: 'Type' },
            { key: 'region', label: 'Region' },
            { key: 'status', label: 'Status', render: (r) => STATUS_TAG[r.status] || r.status },
            { key: 'created', label: 'Created' },
          ]}
          rows={RESOURCES.slice(0, 5)}
        />
      </div>
    </div>
  );
}

function ResourceList({ onCreate }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div>
        <Breadcrumb items={['IBM Cloud', 'Resource list']} />
        <h1 style={{ margin: '16px 0 4px', fontSize: 28, fontWeight: 400, lineHeight: '36px' }}>Resource list</h1>
        <p style={{ margin: 0, fontSize: 16, color: '#525252', lineHeight: '24px' }}>
          All resources in the <strong style={{ fontWeight: 600 }}>default</strong> resource group.
        </p>
      </div>
      <DataTable
        title="All resources"
        description={`${RESOURCES.length} total · 5 active, 1 provisioning, 1 suspended`}
        columns={[
          { key: 'name', label: 'Name' },
          { key: 'type', label: 'Type' },
          { key: 'region', label: 'Region' },
          { key: 'status', label: 'Status', render: (r) => STATUS_TAG[r.status] || r.status },
          { key: 'created', label: 'Created' },
        ]}
        rows={RESOURCES}
      />
    </div>
  );
}

function SettingsPage() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24, maxWidth: 560 }}>
      <div>
        <Breadcrumb items={['IBM Cloud', 'Settings', 'Account']} />
        <h1 style={{ margin: '16px 0 4px', fontSize: 28, fontWeight: 400 }}>Account settings</h1>
        <p style={{ margin: 0, fontSize: 16, color: '#525252' }}>Update your profile and notification preferences.</p>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
        {React.createElement(window.TextInput, { label: 'Full name', value: 'Sam Lee', onChange: () => {} })}
        {React.createElement(window.TextInput, { label: 'Email address', value: 'sam.lee@ibm.com', helper: 'Primary contact for this account.', onChange: () => {} })}
        {React.createElement(window.TextInput, { label: 'API key', value: 'sk_12', error: 'Enter a valid API key.', onChange: () => {} })}
        <div style={{ display: 'flex', gap: 1, marginTop: 16 }}>
          <Button kind="secondary">Cancel</Button>
          <Button kind="primary" icon="checkmark">Save changes</Button>
        </div>
      </div>
    </div>
  );
}

function App() {
  const [active, setActive] = useState('home');
  const [modal, setModal] = useState(false);
  const [toast, setToast] = useState(null);

  return (
    <div style={{ background: '#fff', minHeight: '100vh' }}>
      <UIShellHeader productName="Cloud · Console" />
      <div style={{ display: 'flex' }}>
        <UIShellSideNav items={NAV} active={active} onSelect={setActive} />
        <main style={{ flex: 1, padding: '32px 32px 64px', background: '#f4f4f4', minHeight: 'calc(100vh - 48px)' }}>
          {active === 'home' && <Dashboard setActive={setActive} onCreate={() => setModal(true)} />}
          {active === 'resources' && <ResourceList onCreate={() => setModal(true)} />}
          {active === 'settings' && <SettingsPage />}
          {!['home', 'resources', 'settings'].includes(active) && (
            <div style={{ padding: '64px 0' }}>
              <Breadcrumb items={['IBM Cloud', NAV.find(n => n.id === active)?.label]} />
              <h1 style={{ margin: '16px 0 4px', fontSize: 28, fontWeight: 400 }}>{NAV.find(n => n.id === active)?.label}</h1>
              <p style={{ fontSize: 16, color: '#525252' }}>This surface is stubbed. Navigate Dashboard, Resource list, or Settings for full flows.</p>
              <div style={{ marginTop: 24 }}>
                <Button kind="primary" icon="add" onClick={() => setModal(true)}>Create resource</Button>
              </div>
            </div>
          )}
        </main>

        <Modal
          open={modal}
          title="Create a new resource"
          subtitle="RESOURCES"
          primaryLabel="Create"
          onClose={() => setModal(false)}
          onPrimary={() => { setModal(false); setToast({ kind: 'success', title: 'Resource created', body: 'analytics-warehouse-02 is provisioning.' }); }}
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16, marginTop: 16 }}>
            {React.createElement(window.TextInput, { label: 'Resource name', placeholder: 'my-resource', onChange: () => {} })}
            {React.createElement(window.TextInput, { label: 'Region', value: 'us-south', onChange: () => {} })}
            <div>
              <div style={{ fontSize: 12, color: '#525252', letterSpacing: 0.32, marginBottom: 6 }}>Plan</div>
              <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 14, padding: '6px 0' }}>
                <input type="radio" name="p" defaultChecked style={{ accentColor: '#0f62fe' }}/> Lite — Free
              </label>
              <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 14, padding: '6px 0' }}>
                <input type="radio" name="p" style={{ accentColor: '#0f62fe' }}/> Standard — $99/month
              </label>
              <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 14, padding: '6px 0' }}>
                <input type="radio" name="p" style={{ accentColor: '#0f62fe' }}/> Enterprise — contact sales
              </label>
            </div>
          </div>
        </Modal>

        {toast && (
          <div style={{ position: 'fixed', right: 24, bottom: 96, zIndex: 200 }}>
            <Toast {...toast} onClose={() => setToast(null)} />
          </div>
        )}
      </div>
    </div>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
