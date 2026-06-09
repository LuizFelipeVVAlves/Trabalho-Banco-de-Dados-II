-- =============================================================================
-- Questão 5 — Parte 2/4: Engine de validação (função de trigger GENÉRICA)
-- =============================================================================
-- Uma ÚNICA função serve para qualquer tabela e qualquer coluna de estado.
-- Ela recebe 2 argumentos na criação da trigger (via TG_ARGV):
--   TG_ARGV[0] = nome da máquina cadastrada em dte_maquina
--   TG_ARGV[1] = nome da coluna de estado na tabela alvo
--
-- Para ler o valor da coluna sem conhecer seu nome em tempo de compilação,
-- convertemos a linha (NEW/OLD) para JSON e acessamos pelo nome — é isso que
-- torna a função independente da estrutura da tabela.
--
-- Regras aplicadas:
--   INSERT  -> o valor precisa ser um estado INICIAL da máquina.
--   UPDATE  -> se o estado não mudou, passa direto;
--              se mudou, precisa existir a transição (origem -> destino).
--   NULL    -> rejeitado (estado é obrigatório).
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_dte_validar()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_nome_maquina  TEXT;
    v_nome_coluna   TEXT;
    v_maquina_id    INT;
    v_estado_novo   TEXT;
    v_estado_antigo TEXT;
    v_permitido     BOOLEAN;
BEGIN
    -- Validação de uso: a trigger deve ser criada com exatamente 2 argumentos.
    IF TG_NARGS <> 2 THEN
        RAISE EXCEPTION 'fn_dte_validar exige 2 argumentos: (nome_da_maquina, nome_da_coluna). Recebeu %.', TG_NARGS;
    END IF;
    v_nome_maquina := TG_ARGV[0];
    v_nome_coluna  := TG_ARGV[1];

    -- A máquina precisa estar cadastrada nos metadados.
    SELECT maquina_id INTO v_maquina_id
    FROM dte_maquina
    WHERE nome = v_nome_maquina;

    IF v_maquina_id IS NULL THEN
        RAISE EXCEPTION 'Máquina de estados "%" não está cadastrada em dte_maquina.', v_nome_maquina;
    END IF;

    -- Lê o valor da coluna de estado dinamicamente (sem conhecer a tabela).
    v_estado_novo := row_to_json(NEW) ->> v_nome_coluna;

    IF v_estado_novo IS NULL THEN
        RAISE EXCEPTION 'A coluna de estado "%" não pode ser NULL (máquina "%").', v_nome_coluna, v_nome_maquina;
    END IF;

    IF TG_OP = 'INSERT' THEN
        -- Em um INSERT, só são aceitos estados marcados como iniciais no diagrama.
        SELECT EXISTS (
            SELECT 1 FROM dte_estado
            WHERE maquina_id = v_maquina_id
              AND estado     = v_estado_novo
              AND is_inicial = TRUE
        ) INTO v_permitido;

        IF NOT v_permitido THEN
            RAISE EXCEPTION '"%" não é um estado inicial válido da máquina "%".', v_estado_novo, v_nome_maquina;
        END IF;

    ELSE -- TG_OP = 'UPDATE'
        v_estado_antigo := row_to_json(OLD) ->> v_nome_coluna;

        -- Se o UPDATE não mexeu no estado (ex.: alterou outra coluna), passa direto.
        IF v_estado_antigo IS NOT DISTINCT FROM v_estado_novo THEN
            RETURN NEW;
        END IF;

        -- O estado mudou: a seta (origem -> destino) precisa existir no diagrama.
        SELECT EXISTS (
            SELECT 1 FROM dte_transicao
            WHERE maquina_id    = v_maquina_id
              AND estado_origem = v_estado_antigo
              AND estado_destino = v_estado_novo
        ) INTO v_permitido;

        IF NOT v_permitido THEN
            RAISE EXCEPTION 'Transição inválida: "%" -> "%" na máquina "%".', v_estado_antigo, v_estado_novo, v_nome_maquina;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;
