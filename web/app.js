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

const wsBtn = document.getElementById("whatsapp-btn");

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
      el.status.textContent = "perdido";
      el.note.textContent =
        "Perdi minha mochila na FAG! Me chame no WhatsApp.";
      el.note.classList.remove("hidden");
      if (wsBtn) {
        wsBtn.href = "https://wa.me/5545999999999";
        wsBtn.classList.remove("hidden");
      }
    } else {
      el.title.textContent = "Tag ativa";
      el.status.textContent = "NORMAL";
    }
    return;
  }

  const client = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  const { data, error } = await client
    .from("tags")
    .select("*")
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

  const isLost = Boolean(data.is_lost || data.status === "PERDIDO");

  if (isLost) {
    el.title.textContent = data.label || "Objeto perdido";
    el.status.textContent = "perdido";
    el.subtitle.textContent = "Alguém marcou este item como desaparecido.";

    const message = data.public_message || data.mensagem;
    if (message) {
      el.note.textContent = message;
      el.note.classList.remove("hidden");
    }

    if (data.telefone && wsBtn) {
      const cleanPhone = data.telefone.replace(/\D/g, "");
      const fullPhone = cleanPhone.length > 11 && cleanPhone.startsWith("55")
        ? cleanPhone
        : `55${cleanPhone}`;
      wsBtn.href = `https://wa.me/${fullPhone}`;
      wsBtn.classList.remove("hidden");
    }
  } else {
    el.title.textContent = data.label || "Tag ativa";
    el.status.textContent = (data.status || "NORMAL").toLowerCase();
    el.subtitle.textContent = "Nenhum alerta de perda para este ID.";
    if (wsBtn) {
      wsBtn.classList.add("hidden");
    }
  }
}

const tagId = normalizeId(rawId);
if (!tagId) {
  el.subtitle.textContent = "Passe ?id=0x0001 ou ?id=0x0002 na URL (NFC/QR).";
} else {
  loadTag(tagId);
}
