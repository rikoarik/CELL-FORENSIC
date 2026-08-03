// Cell Forensic E11 — OpenAI-compatible chat proxy (server-side key only).
// Secrets (Supabase Dashboard → Edge Functions → Secrets):
//   OPENAI_API_KEY   (required)
//   OPENAI_BASE_URL  (default https://api.arklabs.biz.id/v1)
//   OPENAI_MODEL     (default cell-forensik)
// Never embed the API key in Flutter / APK / web bundle.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ALLOWED_ACTIONS = new Set([
  "none",
  "focus_sample_a",
  "focus_sample_b",
  "highlight_chloroplast",
  "show_damaged_chloroplast",
  "show_vacuole_damage",
  "focus_membrane",
  "show_membrane_damage",
  "show_water_leak",
  "compare_samples",
  "highlight_cell_wall",
  "show_force_arrows",
  "reset_scene",
]);

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) {
      return json(
        { error: "OPENAI_API_KEY belum dikonfigurasi di Edge secrets" },
        500,
      );
    }

    const baseUrl = (
      Deno.env.get("OPENAI_BASE_URL") ?? "https://api.arklabs.biz.id/v1"
    ).replace(/\/$/, "");
    const model = Deno.env.get("OPENAI_MODEL") ?? "cell-forensik";

    const body = await req.json().catch(() => ({}));
    const message = String(body?.message ?? "").trim();
    const mission = Number(body?.mission ?? 0);

    if (!message) {
      return json({ error: "message wajib diisi" }, 400);
    }
    if (![1, 2, 3].includes(mission)) {
      return json({ error: "mission harus 1, 2, atau 3" }, 400);
    }

    // Block provisional inventing at the proxy boundary too.
    const lower = message.toLowerCase();
    if (
      lower.includes("organel x") ||
      lower.includes("organel y") ||
      lower.includes("membran 1") ||
      lower.includes("membran 2")
    ) {
      return json({
        message:
          "Label itu masih provisional dan belum diverifikasi untuk penilaian. " +
          "Amati struktur yang terlihat pada scene, lalu catat pengamatanmu di " +
          "logbook tanpa mengarang nama organel/membran bernomor.",
        intent: "provisional_label",
        mission,
        target: "",
        ar_action: "none",
        confidence: 1,
      });
    }

    const system = [
      "Kamu asisten investigasi Cell Forensic (Bahasa Indonesia).",
      "Jawab singkat dan bantu siswa mengamati scene AR.",
      "JANGAN mengarang fakta tentang Organel X/Y atau membran 1/2.",
      "Balas HANYA JSON valid (tanpa markdown) dengan skema:",
      '{"message":"...","intent":"...","mission":' +
        mission +
        ',"target":"...","ar_action":"...","confidence":0.0}',
      "ar_action whitelist: " + [...ALLOWED_ACTIONS].join(", "),
      "Pilih ar_action yang cocok dengan misi " +
        mission +
        "; jika ragu pakai none.",
      "confidence 0–1. Jangan sertakan API key atau rahasia.",
    ].join(" ");

    const upstream = await fetch(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0.2,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: system },
          { role: "user", content: message },
        ],
      }),
    });

    if (!upstream.ok) {
      // Surface only short, filtered diagnostics. Never return raw upstream
      // payloads because a provider could echo request headers or secrets.
      const diagnostic = await safeUpstreamDiagnostic(upstream);
      return json({
        error: "upstream_ai_failed",
        status: upstream.status,
        ...diagnostic,
      }, 502);
    }

    const payload = await upstream.json();
    const content = payload?.choices?.[0]?.message?.content;
    const parsed = parseModelJson(content);
    if (!parsed) {
      return json({ error: "invalid_model_json" }, 502);
    }

    const arAction = sanitizeAction(parsed.ar_action);
    const confidence = clamp01(Number(parsed.confidence ?? 0));
    const outMission = Number(parsed.mission ?? mission) || mission;

    return json({
      message: String(parsed.message ?? "").trim() ||
        "Amati scene dan catat di logbook.",
      intent: String(parsed.intent ?? "unknown"),
      mission: outMission,
      target: String(parsed.target ?? ""),
      ar_action: arAction,
      confidence,
    });
  } catch (error) {
    console.error("ai-assistant error", error?.name ?? "error");
    return json({ error: "internal_error" }, 500);
  }
});

function sanitizeAction(value: unknown): string {
  const action = String(value ?? "none").trim().toLowerCase();
  return ALLOWED_ACTIONS.has(action) ? action : "none";
}

function clamp01(n: number): number {
  if (Number.isNaN(n)) return 0;
  return Math.min(1, Math.max(0, n));
}

async function safeUpstreamDiagnostic(
  response: Response,
): Promise<Record<string, string>> {
  const payload = await response.json().catch(() => null);
  if (!payload || typeof payload !== "object") return {};
  const error = (payload as Record<string, unknown>).error;
  const source = error && typeof error === "object"
    ? error as Record<string, unknown>
    : payload as Record<string, unknown>;
  const code = cleanDiagnostic(source.code ?? source.type);
  const message = cleanDiagnostic(source.message);
  return {
    ...(code ? { upstream_code: code } : {}),
    ...(message ? { upstream_message: message } : {}),
  };
}

function cleanDiagnostic(value: unknown): string {
  if (typeof value !== "string") return "";
  return value.replace(/[^a-zA-Z0-9 _./:-]/g, "").trim().slice(0, 160);
}

function parseModelJson(content: unknown): Record<string, unknown> | null {
  if (typeof content !== "string" || !content.trim()) return null;
  let text = content.trim();
  if (text.startsWith("```")) {
    text = text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "");
  }
  try {
    const value = JSON.parse(text);
    return value && typeof value === "object"
      ? value as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
