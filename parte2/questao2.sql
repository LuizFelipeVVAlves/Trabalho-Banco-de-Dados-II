-- regra 1: não permitir faturas duplicadas para um mesmo cliente

CREATE OR REPLACE FUNCTION fn_validar_fatura_duplicada()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN

    -- verifica se já existe uma fatura com os mesmos dados
    IF EXISTS (
        SELECT 1
        FROM invoice i
        WHERE i.customer_id = NEW.customer_id
          AND i.invoice_date = NEW.invoice_date
          AND i.total = NEW.total
          AND i.invoice_id <> COALESCE(NEW.invoice_id, -1)
    ) THEN

        RAISE EXCEPTION
        'Fatura duplicada detectada para o cliente %, data % e valor %.',
        NEW.customer_id,
        NEW.invoice_date,
        NEW.total;

    END IF;

    RETURN NEW;

END;
$$;

-- remove o trigger caso ele já exista
DROP TRIGGER IF EXISTS trg_validar_fatura_duplicada
ON invoice;

-- executa a validação antes de inserir ou atualizar uma fatura
CREATE TRIGGER trg_validar_fatura_duplicada
BEFORE INSERT OR UPDATE
ON invoice
FOR EACH ROW
EXECUTE FUNCTION fn_validar_fatura_duplicada();


-- regra 2: não permitir músicas repetidas na mesma fatura

CREATE OR REPLACE FUNCTION fn_validar_track_duplicada()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN

    -- verifica se a música já está presente na mesma fatura
    IF EXISTS (
        SELECT 1
        FROM invoice_line il
        WHERE il.invoice_id = NEW.invoice_id
          AND il.track_id = NEW.track_id
          AND il.invoice_line_id <> COALESCE(NEW.invoice_line_id, -1)
    ) THEN

        RAISE EXCEPTION
        'A música % já está cadastrada na fatura %.',
        NEW.track_id,
        NEW.invoice_id;

    END IF;

    RETURN NEW;

END;
$$;

-- remove o trigger caso ele já exista
DROP TRIGGER IF EXISTS trg_validar_track_duplicada
ON invoice_line;

-- executa a validação antes de inserir ou atualizar um item da fatura
CREATE TRIGGER trg_validar_track_duplicada
BEFORE INSERT OR UPDATE
ON invoice_line
FOR EACH ROW
EXECUTE FUNCTION fn_validar_track_duplicada();


-- regra 3: não permitir ciclos na hierarquia de funcionários

CREATE OR REPLACE FUNCTION fn_validar_hierarquia_funcionarios()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
DECLARE
    v_supervisor INTEGER;
BEGIN

    -- permite funcionários sem supervisor definido
    IF NEW.reports_to IS NULL THEN
        RETURN NEW;
    END IF;

    -- impede que o funcionário seja supervisor de si mesmo
    IF NEW.employee_id = NEW.reports_to THEN
        RAISE EXCEPTION
            'O funcionário % não pode supervisionar a si mesmo.',
            NEW.employee_id;
    END IF;

    -- inicia a verificação da cadeia hierárquica
    v_supervisor := NEW.reports_to;

    -- percorre todos os supervisores da cadeia
    WHILE v_supervisor IS NOT NULL LOOP

        -- verifica se existe um ciclo envolvendo o funcionário
        IF v_supervisor = NEW.employee_id THEN
            RAISE EXCEPTION
                'A atualização criaria um ciclo na hierarquia de funcionários.';
        END IF;

        -- obtém o próximo supervisor da cadeia
        SELECT reports_to
        INTO v_supervisor
        FROM employee
        WHERE employee_id = v_supervisor;

    END LOOP;

    RETURN NEW;

END;
$$;

-- remove o trigger caso ele já exista
DROP TRIGGER IF EXISTS trg_validar_hierarquia_funcionarios
ON employee;

-- executa a validação antes de inserir ou atualizar funcionários
CREATE TRIGGER trg_validar_hierarquia_funcionarios
BEFORE INSERT OR UPDATE
ON employee
FOR EACH ROW
EXECUTE FUNCTION fn_validar_hierarquia_funcionarios();