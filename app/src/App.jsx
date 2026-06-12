// The build-time env var VITE_ENV_NAME is injected by the pipeline so we can SEE
// which server (dev/prod) served the page.
const envName = import.meta.env.VITE_ENV_NAME || 'local'

export default function App() {
  return (
    <main style={{ fontFamily: 'system-ui', textAlign: 'center', marginTop: '15vh' }}>
      <h1>🚀 CI/CD Frontend Demo</h1>
      <p>This page was built and deployed by a GitHub Actions pipeline.</p>
      <p style={{
        display: 'inline-block', padding: '8px 16px', borderRadius: 8,
        background: envName === 'production' ? '#16a34a' : '#2563eb', color: 'white',
      }}>
        Environment: <strong>{envName}</strong>
      </p>
      <p style={{ color: '#666', marginTop: 24 }}>Build: {new Date().toISOString()}</p>
    </main>
  )
}
