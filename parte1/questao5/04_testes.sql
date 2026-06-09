-- =============================================================================
-- Questão 5 — Parte 4/4: Cenário de teste
-- =============================================================================
-- Demonstra a engine funcionando na tabela invoice. Cada caso que DEVE falhar
-- fica protegido por um sub-bloco BEGIN/EXCEPTION, assim o script roda até o
-- fim e imprime um relatório legível:
--   [OK]            comportamento permitido aconteceu
--   [ERRO ESPERADO] violação foi corretamente bloqueada pela trigger
--   [FALHA]         a engine NÃO se comportou como deveria
--
-- Rode com psql para ver as mensagens (RAISE NOTICE).
-- =============================================================================

DO $$
BEGIN
    -- Limpeza prévia (permite re-rodar o teste quantas vezes quiser).
    DELETE FROM invoice WHERE invoice_id IN (99001, 99002);

    RAISE NOTICE '=== Cenário de teste: máquina invoice_status na tabela invoice ===';

    ---------------------------------------------------------------------------
    -- Caso 1: INSERT com estado inicial válido (PENDENTE) -> deve PASSAR
    ---------------------------------------------------------------------------
    BEGIN
        INSERT INTO invoice (invoice_id, customer_id, invoice_date, total, status)
        VALUES (99001, 1, now(), 10.00, 'PENDENTE');
        RAISE NOTICE '[OK] Caso 1: INSERT com estado inicial PENDENTE foi aceito.';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '[FALHA] Caso 1: INSERT válido foi rejeitado: %', SQLERRM;
    END;

    ---------------------------------------------------------------------------
    -- Caso 2: INSERT com estado que NÃO é inicial (PAGA) -> deve FALHAR
    ---------------------------------------------------------------------------
    BEGIN
        INSERT INTO invoice (invoice_id, customer_id, invoice_date, total, status)
        VALUES (99002, 1, now(), 10.00, 'PAGA');
        RAISE NOTICE '[FALHA] Caso 2: INSERT com estado não-inicial deveria ter sido bloqueado!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '[ERRO ESPERADO] Caso 2: %', SQLERRM;
    END;

    ---------------------------------------------------------------------------
    -- Caso 3: UPDATE PENDENTE -> PAGA (transição existe) -> deve PASSAR
    ---------------------------------------------------------------------------
    BEGIN
        UPDATE invoice SET status = 'PAGA' WHERE invoice_id = 99001;
        RAISE NOTICE '[OK] Caso 3: transição PENDENTE -> PAGA foi aceita.';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '[FALHA] Caso 3: transição válida foi rejeitada: %', SQLERRM;
    END;

    ---------------------------------------------------------------------------
    -- Caso 4: UPDATE PAGA -> CANCELADA (transição NÃO existe) -> deve FALHAR
    -- (a spec listava PENDENTE -> ENVIADA; trocamos por PAGA -> CANCELADA, que
    --  é igualmente uma seta inexistente, pois a linha 99001 já está em PAGA)
    ---------------------------------------------------------------------------
    BEGIN
        UPDATE invoice SET status = 'CANCELADA' WHERE invoice_id = 99001;
        RAISE NOTICE '[FALHA] Caso 4: transição inexistente deveria ter sido bloqueada!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '[ERRO ESPERADO] Caso 4: %', SQLERRM;
    END;

    ---------------------------------------------------------------------------
    -- Caso 5: UPDATE PAGA -> ENVIADA (transição existe) -> deve PASSAR
    ---------------------------------------------------------------------------
    BEGIN
        UPDATE invoice SET status = 'ENVIADA' WHERE invoice_id = 99001;
        RAISE NOTICE '[OK] Caso 5: transição PAGA -> ENVIADA foi aceita.';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '[FALHA] Caso 5: transição válida foi rejeitada: %', SQLERRM;
    END;

    ---------------------------------------------------------------------------
    -- Caso 6: UPDATE de outra coluna SEM mudar o estado -> deve PASSAR
    ---------------------------------------------------------------------------
    BEGIN
        UPDATE invoice SET total = 20.00 WHERE invoice_id = 99001;
        RAISE NOTICE '[OK] Caso 6: UPDATE que não altera o estado foi aceito.';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '[FALHA] Caso 6: UPDATE sem mudança de estado foi rejeitado: %', SQLERRM;
    END;

    ---------------------------------------------------------------------------
    -- Caso 7a: UPDATE ENVIADA -> REEMBOLSADA (transição existe) -> deve PASSAR
    ---------------------------------------------------------------------------
    BEGIN
        UPDATE invoice SET status = 'REEMBOLSADA' WHERE invoice_id = 99001;
        RAISE NOTICE '[OK] Caso 7a: transição ENVIADA -> REEMBOLSADA foi aceita.';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '[FALHA] Caso 7a: transição válida foi rejeitada: %', SQLERRM;
    END;

    ---------------------------------------------------------------------------
    -- Caso 7b: sair de estado final (REEMBOLSADA -> PAGA) -> deve FALHAR
    -- (estado final não tem setas de saída em dte_transicao)
    ---------------------------------------------------------------------------
    BEGIN
        UPDATE invoice SET status = 'PAGA' WHERE invoice_id = 99001;
        RAISE NOTICE '[FALHA] Caso 7b: saída de estado final deveria ter sido bloqueada!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '[ERRO ESPERADO] Caso 7b: %', SQLERRM;
    END;

    ---------------------------------------------------------------------------
    -- Caso 8: estado NULL -> deve FALHAR
    -- (a trigger BEFORE roda antes da checagem NOT NULL da coluna, então a
    --  mensagem vem da engine; a engine cobre também o caso genérico de
    --  colunas de estado sem NOT NULL)
    ---------------------------------------------------------------------------
    BEGIN
        UPDATE invoice SET status = NULL WHERE invoice_id = 99001;
        RAISE NOTICE '[FALHA] Caso 8: estado NULL deveria ter sido bloqueado!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '[ERRO ESPERADO] Caso 8: %', SQLERRM;
    END;


    ---------------------------------------------------------------------------
    -- Caso 9: INSERT PENDENTE e UPDATE PENDENTE -> CANCELADA -> deve PASSAR
    -- (cobre a segunda saída de PENDENTE e a chegada a um estado final)
    ---------------------------------------------------------------------------
    BEGIN
        INSERT INTO invoice (invoice_id, customer_id, invoice_date, total, status)
        VALUES (99002, 1, now(), 10.00, 'PENDENTE');
        UPDATE invoice SET status = 'CANCELADA' WHERE invoice_id = 99002;
        RAISE NOTICE '[OK] Caso 9: transição PENDENTE -> CANCELADA foi aceita.';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '[FALHA] Caso 9: fluxo válido foi rejeitado: %', SQLERRM;
    END;

    -- Limpeza final: remove as linhas criadas pelo teste.
    DELETE FROM invoice WHERE invoice_id IN (99001, 99002);

    RAISE NOTICE '=== Fim do cenário de teste ===';
END;
$$;
