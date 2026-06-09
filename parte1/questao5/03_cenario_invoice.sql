-- =============================================================================
-- Questão 5 — Parte 3/4: Cenário de uso na tabela invoice do Chinook
-- =============================================================================
-- Diagrama de transição de estados (DTE) do ciclo de vida de uma fatura:
--
--   PENDENTE ──> PAGA ──> ENVIADA ──> REEMBOLSADA (final)
--      │            └────────────────────^
--      └──────> CANCELADA (final)
--
-- Estado inicial: PENDENTE. Estados finais: CANCELADA, REEMBOLSADA
-- (finais = sem transições de saída).
--
-- Este script é re-rodável: apaga e recadastra a máquina a cada execução.
-- =============================================================================

-- 1) Adiciona a coluna de estado na tabela real do Chinook.
--    Linhas já existentes recebem o DEFAULT ('PENDENTE').
ALTER TABLE invoice
    ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'PENDENTE';

-- 2) (Re)cadastra a máquina. O ON DELETE CASCADE limpa estados e transições.
DELETE FROM dte_maquina WHERE nome = 'invoice_status';

INSERT INTO dte_maquina (nome, descricao)
VALUES ('invoice_status', 'Ciclo de vida de uma fatura (invoice) do Chinook');

-- 3) Estados do diagrama.
INSERT INTO dte_estado (maquina_id, estado, is_inicial, is_final)
SELECT m.maquina_id, e.estado, e.is_inicial, e.is_final
FROM dte_maquina m,
     (VALUES
        ('PENDENTE',    TRUE,  FALSE),
        ('PAGA',        FALSE, FALSE),
        ('ENVIADA',     FALSE, FALSE),
        ('CANCELADA',   FALSE, TRUE),
        ('REEMBOLSADA', FALSE, TRUE)
     ) AS e (estado, is_inicial, is_final)
WHERE m.nome = 'invoice_status';

-- 4) Transições permitidas (as setas do diagrama).
INSERT INTO dte_transicao (maquina_id, estado_origem, estado_destino)
SELECT m.maquina_id, t.origem, t.destino
FROM dte_maquina m,
     (VALUES
        ('PENDENTE', 'PAGA'),
        ('PENDENTE', 'CANCELADA'),
        ('PAGA',     'ENVIADA'),
        ('PAGA',     'REEMBOLSADA'),
        ('ENVIADA',  'REEMBOLSADA')
     ) AS t (origem, destino)
WHERE m.nome = 'invoice_status';

-- 5) Anexa a engine genérica à tabela: UMA linha de código por tabela protegida.
DROP TRIGGER IF EXISTS trg_dte_invoice ON invoice;

CREATE TRIGGER trg_dte_invoice
    BEFORE INSERT OR UPDATE ON invoice
    FOR EACH ROW
    EXECUTE FUNCTION fn_dte_validar('invoice_status', 'status');
