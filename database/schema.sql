-- Criação da tabela de Tags
CREATE TABLE IF NOT EXISTS public.tags (
    id TEXT PRIMARY KEY,                       -- Ex: '0x0001'
    status TEXT NOT NULL DEFAULT 'NORMAL',     -- 'NORMAL' ou 'PERDIDO'
    mensagem TEXT DEFAULT '',                 -- Mensagem personalizada do dono
    telefone TEXT DEFAULT '',                 -- WhatsApp / Telefone de contato
    latitude DOUBLE PRECISION,                 -- Posição GPS
    longitude DOUBLE PRECISION,                -- Posição GPS
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar leitura pública para a página Web de resgate
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir leitura pública de tags"
ON public.tags FOR SELECT
USING (true);
