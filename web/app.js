const SUPABASE_URL = "https://kzlphhmyyxtujqcfgslr.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_4Zcucs4FqucvNfDcBlY5rw_v5KVjSrN";

const params = new URLSearchParams(window.location.search);
const rawId = (params.get("id") || "").trim();

const el = {
  title: document.getElementById("title"),
  subtitle: document.getElementById("subtitle"),
  tagId: document.getElementById("tag-id"),
  status: document.getElementById("tag-status"),
  note: document.getElementById("owner-note"),
  error: document.getElementById("error"),
};

function normalizeId(value) {
  if (!value) return null;
  const hex = value.replace(/^0x/i, "").toUpperCase().padStart(4, "0");
  if (!/^[0-9A-F]{4}$/.test(hex)) return null;
  return `0x${hex}`;
}

function showError(message) {
  el.error.textContent = message;
  el.error.classList.remove("hidden");
}

async function loadTag(tagId) {
  el.tagId.textContent = tagId;

  if (!window.supabase || SUPABASE_URL.includes("YOUR_PROJECT")) {
    el.subtitle.textContent =
      "Configure SUPABASE_URL e a anon key em web/app.js para buscar o estado real.";
    el.status.textContent = "demo local";
    if (tagId === "0x0002") {
      el.title.textContent = "Objeto perdido";
      el.status.textContent = "PERDIDO";
      el.note.textContent =
        "Perdi minha mochila na FAG! Me chame no WhatsApp. Contato: 45999999999";
      el.note.classList.remove("hidden");
    } else {
      el.title.textContent = "Tag ativa";
      el.status.textContent = "NORMAL";
    }
    return;
  }

  const client = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  const { data, error } = await client
    .from("tags")
    .select("id, status, mensagem, telefone, latitude, longitude")
    .eq("id", tagId)
    .maybeSingle();

  if (error) {
    showError("Não foi possível consultar o Supabase.");
    return;
  }

  if (!data) {
    el.title.textContent = "Tag desconhecida";
    el.status.textContent = "não cadastrada";
    el.subtitle.textContent = "Este ID não existe na base.";
    return;
  }

  el.tagId.textContent = data.id;
  el.status.textContent = data.status;

  if (data.status === "PERDIDO") {
    el.title.textContent = "Objeto perdido";
    el.subtitle.textContent = "Alguém marcou este item como desaparecido.";
    const parts = [];
    if (data.mensagem) {
      parts.push(data.mensagem);
    }
    if (data.telefone) {
      parts.push("Contato: " + data.telefone);
    }
    if (parts.length) {
      el.note.textContent = parts.join(" ");
      el.note.classList.remove("hidden");
    }
  } else {
    el.title.textContent = "Tag ativa";
    el.subtitle.textContent = "Nenhum alerta de perda para este ID.";
  }
}

const tagId = normalizeId(rawId);
if (!tagId) {
  el.subtitle.textContent = "Passe ?id=0x0001 ou ?id=0x0002 na URL (NFC/QR).";
} else {
  loadTag(tagId);
}
