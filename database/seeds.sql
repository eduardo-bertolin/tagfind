-- Inserindo dados de teste para validação inicial
INSERT INTO public.tags (id, status, mensagem, telefone, latitude, longitude)
VALUES
    ('0x0001', 'NORMAL', '', '', -24.9558, -53.4552),
    ('0x0002', 'PERDIDO', 'Perdi minha mochila na FAG! Me chame no WhatsApp.', '45999999999', -24.9558, -53.4552)
ON CONFLICT (id) DO NOTHING;
