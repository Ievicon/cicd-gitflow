import { useEffect, useState } from 'react'
import './App.css'

// ENV is set at DEPLOY time by the pipeline (window.__ENV__ in /env.js) so the
// SAME build can be promoted DEV -> STAGING -> PROD and still show where it runs.
// VERSION / COMMIT / BUILT_AT are baked at BUILD time (same for every server).
const ENV = (typeof window !== 'undefined' && window.__ENV__) || 'local'
const VERSION = import.meta.env.VITE_APP_VERSION || '1.0.0'
const COMMIT = import.meta.env.VITE_GIT_SHA || 'local-build'
const BUILT_AT = import.meta.env.VITE_BUILT_AT || new Date().toISOString()

// Per-environment look & feel so each server is unmistakable at a glance.
const THEMES = {
  local:       { label: 'LOCAL',       color: '#64748b', emoji: '💻' },
  development: { label: 'DEVELOPMENT', color: '#2563eb', emoji: '🛠️' },
  staging:     { label: 'STAGING',     color: '#d97706', emoji: '🧪' },
  production:  { label: 'PRODUCTION',  color: '#16a34a', emoji: '🚀' },
}

export default function App() {
  const theme = THEMES[ENV] || THEMES.local
  const [count, setCount] = useState(0)

  // Paint the accent color on the page background glow.
  useEffect(() => {
    document.documentElement.style.setProperty('--accent', theme.color)
  }, [theme.color])

  return (
    <main className="app">
      <span className="env-badge" style={{ background: theme.color }}>
        {theme.emoji} {theme.label}
      </span>

      <h1>Git Flow Promotion Demo</h1>
      <p className="subtitle">
        The same build is promoted across environments by GitHub Actions and Princewill.
      </p>

      <div className="card">
        <Row label="Environment" value={theme.label} accent />
        <Row label="Version" value={VERSION} />
        <Row label="Commit" value={COMMIT.slice(0, 7)} />
        <Row label="Built at" value={BUILT_AT} />
      </div>

      <button className="counter" onClick={() => setCount((c) => c + 1)}>
        Clicked {count} time{count === 1 ? '' : 's'}
      </button>

      <ol className="flow">
        <li className={ENV === 'development' ? 'on' : ''}>feature/* → <b>develop</b> → DEV</li>
        <li className={ENV === 'staging' ? 'on' : ''}>release/* → <b>staging</b> → STAGING</li>
        <li className={ENV === 'production' ? 'on' : ''}>main → <b>production</b> → PROD (approval)</li>
      </ol>
    </main>
  )
}

function Row({ label, value, accent }) {
  return (
    <div className="row">
      <span className="row-label">{label}</span>
      <span className="row-value" style={accent ? { color: 'var(--accent)' } : undefined}>
        {value}
      </span>
    </div>
  )
}
