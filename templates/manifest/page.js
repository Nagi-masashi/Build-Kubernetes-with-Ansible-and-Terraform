"use client";
import { useState, useRef } from "react";

// ── Configuration ──────────────────────────────────────────────────────────────
const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001";

const INDUSTRIES = [
  { value: "realestate", label: "🏠 不動産", labelEn: "Real Estate" },
  { value: "legal",      label: "⚖️ 法律",   labelEn: "Legal" },
  { value: "medical",    label: "🏥 医療",   labelEn: "Medical" },
  { value: "hr",         label: "👥 人事採用", labelEn: "HR / Recruiting" },
];

const DOC_TYPES = [
  { value: "proposal",  label: "提案書",   labelEn: "Proposal" },
  { value: "email",     label: "営業メール", labelEn: "Sales Email" },
  { value: "guideline", label: "案内文",   labelEn: "Guideline" },
  { value: "report",    label: "レポート",  labelEn: "Report" },
  { value: "summary",   label: "要約",     labelEn: "Summary" },
];

// ── Main Page ──────────────────────────────────────────────────────────────────
export default function Home() {
  const [industry, setIndustry]   = useState("realestate");
  const [docType,  setDocType]    = useState("proposal");
  const [context,  setContext]    = useState("");
  const [language, setLanguage]   = useState("ja");
  const [output,   setOutput]     = useState("");
  const [loading,  setLoading]    = useState(false);
  const [error,    setError]      = useState("");
  const outputRef = useRef(null);

  async function handleGenerate() {
    if (!context.trim() || loading) return;
    setLoading(true);
    setOutput("");
    setError("");

    try {
      const res = await fetch(`${API_URL}/api/generate`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ industry, docType, context, language }),
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || "Generation failed.");
      }

      // Read SSE stream
      const reader = res.body.getReader();
      const decoder = new TextDecoder();

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const lines = decoder.decode(value).split("\n");
        for (const line of lines) {
          if (!line.startsWith("data: ")) continue;
          const payload = line.slice(6);
          if (payload === "[DONE]") break;
          try {
            const { text } = JSON.parse(payload);
            setOutput(prev => prev + text);
            // Auto-scroll output
            outputRef.current?.scrollTo({ top: outputRef.current.scrollHeight, behavior: "smooth" });
          } catch { /* skip malformed chunks */ }
        }
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  function handleCopy() {
    navigator.clipboard.writeText(output);
  }

  const selectedIndustry = INDUSTRIES.find(i => i.value === industry);

  return (
    <main style={{ minHeight: "100vh", background: "#f9f8f5", padding: "2rem 1rem", fontFamily: "system-ui, sans-serif" }}>
      <div style={{ maxWidth: 760, margin: "0 auto" }}>

        {/* Header */}
        <div style={{ marginBottom: "2rem" }}>
          <h1 style={{ fontSize: 26, fontWeight: 600, margin: "0 0 6px", color: "#1a1a18" }}>
            Vertical AI Writer
          </h1>
          <p style={{ fontSize: 14, color: "#6b6b65", margin: 0 }}>
            業界特化AIライティングアシスタント — Powered by Claude
          </p>
        </div>

        {/* Controls */}
        <div style={{ background: "#fff", border: "1px solid #e5e3dc", borderRadius: 12, padding: "1.5rem", marginBottom: "1rem" }}>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 12, marginBottom: 16 }}>

            {/* Industry */}
            <div>
              <label style={labelStyle}>業界 / Industry</label>
              <select value={industry} onChange={e => setIndustry(e.target.value)} style={selectStyle}>
                {INDUSTRIES.map(i => (
                  <option key={i.value} value={i.value}>{i.label} {i.labelEn}</option>
                ))}
              </select>
            </div>

            {/* Doc type */}
            <div>
              <label style={labelStyle}>文書タイプ</label>
              <select value={docType} onChange={e => setDocType(e.target.value)} style={selectStyle}>
                {DOC_TYPES.map(d => (
                  <option key={d.value} value={d.value}>{d.label} / {d.labelEn}</option>
                ))}
              </select>
            </div>

            {/* Language */}
            <div>
              <label style={labelStyle}>出力言語</label>
              <select value={language} onChange={e => setLanguage(e.target.value)} style={selectStyle}>
                <option value="ja">日本語</option>
                <option value="en">English</option>
              </select>
            </div>
          </div>

          {/* Context textarea */}
          <label style={labelStyle}>
            背景情報・指示（{context.length} / 3000文字）
          </label>
          <textarea
            value={context}
            onChange={e => setContext(e.target.value)}
            placeholder={`例: 物件名「サンシャイン渋谷302」、賃料13万円、1LDK 42㎡、築8年、最寄り駅徒歩3分。ターゲットは30代単身者向けに提案書を作成してください。`}
            maxLength={3000}
            rows={5}
            style={{ ...inputStyle, width: "100%", resize: "vertical", marginTop: 6 }}
          />

          <button
            onClick={handleGenerate}
            disabled={loading || !context.trim()}
            style={{
              ...btnStyle,
              background: loading || !context.trim() ? "#c8c5be" : "#534AB7",
              cursor: loading || !context.trim() ? "not-allowed" : "pointer",
            }}
          >
            {loading ? "生成中..." : `${selectedIndustry?.label} 文書を生成`}
          </button>
        </div>

        {/* Error */}
        {error && (
          <div style={{ background: "#fcebeb", border: "1px solid #f09595", borderRadius: 8, padding: "0.75rem 1rem", color: "#791f1f", fontSize: 14, marginBottom: "1rem" }}>
            ⚠️ {error}
          </div>
        )}

        {/* Output */}
        {(output || loading) && (
          <div style={{ background: "#fff", border: "1px solid #e5e3dc", borderRadius: 12, padding: "1.5rem" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
              <span style={{ fontSize: 13, fontWeight: 500, color: "#444" }}>生成結果</span>
              {output && (
                <button onClick={handleCopy} style={{ fontSize: 12, color: "#534AB7", background: "#EEEDFE", border: "none", borderRadius: 6, padding: "4px 12px", cursor: "pointer" }}>
                  コピー
                </button>
              )}
            </div>
            <div
              ref={outputRef}
              style={{ whiteSpace: "pre-wrap", fontSize: 14, lineHeight: 1.75, color: "#1a1a18", maxHeight: 480, overflowY: "auto" }}
            >
              {output}
              {loading && <span style={{ animation: "blink 1s infinite", opacity: 0.5 }}>▌</span>}
            </div>
          </div>
        )}
      </div>

      <style>{`@keyframes blink { 0%,100%{opacity:0.5} 50%{opacity:0} }`}</style>
    </main>
  );
}

// ── Inline styles ──────────────────────────────────────────────────────────────
const labelStyle = { display: "block", fontSize: 12, fontWeight: 500, color: "#6b6b65", marginBottom: 4 };
const selectStyle = { width: "100%", padding: "8px 10px", border: "1px solid #d3d1c7", borderRadius: 8, fontSize: 13, color: "#1a1a18", background: "#fff" };
const inputStyle  = { padding: "10px 12px", border: "1px solid #d3d1c7", borderRadius: 8, fontSize: 14, color: "#1a1a18", background: "#fff", outline: "none", boxSizing: "border-box" };
const btnStyle    = { marginTop: 14, padding: "10px 24px", border: "none", borderRadius: 8, color: "#fff", fontSize: 14, fontWeight: 500, transition: "background .2s" };
