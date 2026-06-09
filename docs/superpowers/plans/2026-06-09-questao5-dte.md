# Questão 5 (Parte 1) — Validação de DTE genérica — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Engine genérica em PL/pgSQL que valida valores e transições de colunas de estado contra um Diagrama de Transição de Estados (DTE) armazenado como metadados, demonstrada na tabela `invoice` do Chinook.

**Architecture:** Três tabelas de metadados (`dte_maquina`, `dte_estado`, `dte_transicao`) guardam o diagrama como dados. Uma única função de trigger `fn_dte_validar()` parametrizada via `TG_ARGV` (nome da máquina + nome da coluna) valida qualquer tabela/coluna. Cenário de teste: `ALTER TABLE invoice ADD COLUMN status` + trigger + script de testes com `[OK]`/`[ERRO ESPERADO]`.

**Tech Stack:** PostgreSQL 16 (Docker, container `bd2_postgres`, database `chinook`, user `bd2`). Spec: `docs/superpowers/specs/2026-06-09-questao5-dte-design.md`.

**Convenções do repositório:** comentários em português, tom didático (ver `parte1/questao2.sql`). Scripts idempotentes (re-rodáveis). Chinook v1.4.5 em snake_case (`invoice`, não `Invoice`).

**Como rodar SQL (na raiz do projeto, PowerShell ou bash):**
```bash
docker exec -i bd2_postgres psql -U bd2 -d chinook -v ON_ERROR_STOP=1 < parte1/questao5/ARQUIVO.sql
```

**Fato verificado do schema:** `invoice(invoice_id INT NOT NULL PK sem sequence, customer_id INT NOT NULL FK, invoice_date TIMESTAMP NOT NULL, total NUMERIC(10,2) NOT NULL, billing_* opcionais)`. Testes usam `invoice_id` explícitos 99001/99002 e `customer_id = 1` (existe no Chinook).

---

## File Structure

```
parte1/questao5/
├── 01_metadados.sql        # tabelas dte_maquina / dte_estado / dte_transicao
├── 02_engine.sql           # função genérica fn_dte_validar()
├── 03_cenario_invoice.sql  # ALTER invoice + popular DTE + anexar trigger
├── 04_testes.sql           # cenário de teste com casos [OK]/[ERRO ESPERADO]
└── README.md               # ordem de execução e instruções
```

Também modifica: `README.md` (raiz) — seção "Estrutura do repositório".

---

### Task 0: Garantir infraestrutura de pé

**Files:** nenhum (verificação).

- [ ] **Step 1: Subir o container e conferir o banco**

Run:
```bash
docker compose up -d
docker exec bd2_postgres psql -U bd2 -d chinook -c "SELECT count(*) FROM invoice;"
```
Expected: `count` = `412` (ou similar > 0). Se o database `chinook` não existir, recarregar: `docker exec -i bd2_postgres psql -U bd2 -d bd2 -v ON_ERROR_STOP=1 < initdb/01_chinook.sql`.

---

### Task 1: Tabelas de metadados do DTE

**Files:**
- Create: `parte1/questao5/01_metadados.sql`

- [ ] **Step 1: Escrever o script**

```sql
-- =============================================================================
-- Questão 5 — Parte 1/4: Tabelas de metadados do DTE
-- =============================================================================
-- A ideia central: em vez de escrever o diagrama de transição de estados (DTE)
-- dentro de código (IF/CASE), nós guardamos o diagrama como DADOS nestas
-- tabelas. Assim, criar um novo DTE para outra tabela/coluna é só inserir
-- linhas — nenhuma linha de código precisa ser escrita ou alterada.
-- =============================================================================

-- Cada linha aqui é um diagrama (uma "máquina de estados") completo.
CREATE TABLE IF NOT EXISTS dte_maquina (
    maquina_id SERIAL PRIMARY KEY,
    nome       VARCHAR(100) NOT NULL UNIQUE, -- nome usado para referenciar a máquina na trigger
    descricao  TEXT
);

-- Os estados (círculos do diagrama) de cada máquina.
CREATE TABLE IF NOT EXISTS dte_estado (
    maquina_id INT NOT NULL REFERENCES dte_maquina (maquina_id) ON DELETE CASCADE,
    estado     VARCHAR(100) NOT NULL,
    is_inicial BOOLEAN NOT NULL DEFAULT FALSE, -- pode ser usado em um INSERT?
    is_final   BOOLEAN NOT NULL DEFAULT FALSE, -- estado terminal (informativo: um estado final é aquele sem transições de saída)
    PRIMARY KEY (maquina_id, estado)
);

-- As transições (setas do diagrama). Cada linha = uma seta permitida.
-- As FKs compostas garantem que origem e destino sejam estados declarados.
CREATE TABLE IF NOT EXISTS dte_transicao (
    maquina_id     INT NOT NULL,
    estado_origem  VARCHAR(100) NOT NULL,
    estado_destino VARCHAR(100) NOT NULL,
    PRIMARY KEY (maquina_id, estado_origem, estado_destino),
    FOREIGN KEY (maquina_id, estado_origem)
        REFERENCES dte_estado (maquina_id, estado) ON DELETE CASCADE,
    FOREIGN KEY (maquina_id, estado_destino)
        REFERENCES dte_estado (maquina_id, estado) ON DELETE CASCADE
);
```

- [ ] **Step 2: Rodar e verificar**

Run:
```bash
docker exec -i bd2_postgres psql -U bd2 -d chinook -v ON_ERROR_STOP=1 < parte1/questao5/01_metadados.sql
docker exec bd2_postgres psql -U bd2 -d chinook -c "\dt dte_*"
```
Expected: `CREATE TABLE` ×3; `\dt` lista `dte_maquina`, `dte_estado`, `dte_transicao`.

- [ ] **Step 3: Commit**

```bash
git add parte1/questao5/01_metadados.sql
git commit -m "feat(questao5): tabelas de metadados do DTE"
```

---

### Task 2: Engine — função de trigger genérica

**Files:**
- Create: `parte1/questao5/02_engine.sql`

- [ ] **Step 1: Escrever o script**

```sql
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
```

- [ ] **Step 2: Rodar e verificar**

Run:
```bash
docker exec -i bd2_postgres psql -U bd2 -d chinook -v ON_ERROR_STOP=1 < parte1/questao5/02_engine.sql
docker exec bd2_postgres psql -U bd2 -d chinook -c "\df fn_dte_validar"
```
Expected: `CREATE FUNCTION`; `\df` lista `fn_dte_validar` retornando `trigger`.

- [ ] **Step 3: Commit**

```bash
git add parte1/questao5/02_engine.sql
git commit -m "feat(questao5): função de trigger genérica fn_dte_validar"
```

---

### Task 3: Cenário — DTE de status da Invoice

**Files:**
- Create: `parte1/questao5/03_cenario_invoice.sql`

- [ ] **Step 1: Escrever o script**

```sql
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
```

- [ ] **Step 2: Rodar e verificar**

Run:
```bash
docker exec -i bd2_postgres psql -U bd2 -d chinook -v ON_ERROR_STOP=1 < parte1/questao5/03_cenario_invoice.sql
docker exec bd2_postgres psql -U bd2 -d chinook -c "SELECT status, count(*) FROM invoice GROUP BY status;"
docker exec bd2_postgres psql -U bd2 -d chinook -c "SELECT count(*) AS transicoes FROM dte_transicao;"
```
Expected: todas as invoices com `PENDENTE`; `transicoes` = 5.

- [ ] **Step 3: Verificar idempotência (rodar duas vezes)**

Run o mesmo script de novo:
```bash
docker exec -i bd2_postgres psql -U bd2 -d chinook -v ON_ERROR_STOP=1 < parte1/questao5/03_cenario_invoice.sql
```
Expected: sem erros (DELETE + reinsert, `IF NOT EXISTS`, `DROP TRIGGER IF EXISTS`).

- [ ] **Step 4: Commit**

```bash
git add parte1/questao5/03_cenario_invoice.sql
git commit -m "feat(questao5): cenário DTE invoice_status na tabela invoice"
```

---

### Task 4: Script de testes

**Files:**
- Create: `parte1/questao5/04_testes.sql`

- [ ] **Step 1: Escrever o script**

```sql
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
    -- Caso 7: sair de estado final (ENVIADA -> REEMBOLSADA -> tentar PAGA)
    ---------------------------------------------------------------------------
    BEGIN
        UPDATE invoice SET status = 'REEMBOLSADA' WHERE invoice_id = 99001; -- válida
        UPDATE invoice SET status = 'PAGA'        WHERE invoice_id = 99001; -- final não tem saída
        RAISE NOTICE '[FALHA] Caso 7: saída de estado final deveria ter sido bloqueada!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '[ERRO ESPERADO] Caso 7: %', SQLERRM;
    END;

    ---------------------------------------------------------------------------
    -- Caso 8: estado NULL -> deve FALHAR
    ---------------------------------------------------------------------------
    BEGIN
        UPDATE invoice SET status = NULL WHERE invoice_id = 99001;
        RAISE NOTICE '[FALHA] Caso 8: estado NULL deveria ter sido bloqueado!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '[ERRO ESPERADO] Caso 8: %', SQLERRM;
    END;

    -- Limpeza final: remove as linhas criadas pelo teste.
    DELETE FROM invoice WHERE invoice_id IN (99001, 99002);

    RAISE NOTICE '=== Fim do cenário de teste ===';
END;
$$;
```

Nota: o Caso 8 dispara a checagem da própria engine **ou** o `NOT NULL` da coluna — ambos bloqueiam; a engine cobre o caso genérico em que a coluna não tem `NOT NULL`.

- [ ] **Step 2: Rodar e verificar o relatório**

Run:
```bash
docker exec -i bd2_postgres psql -U bd2 -d chinook < parte1/questao5/04_testes.sql
```
Expected (via NOTICE): Casos 1, 3, 5, 6 com `[OK]`; Casos 2, 4, 7, 8 com `[ERRO ESPERADO]`; **nenhum** `[FALHA]`.

- [ ] **Step 3: Verificar que o teste é re-rodável e não deixa lixo**

Run:
```bash
docker exec -i bd2_postgres psql -U bd2 -d chinook < parte1/questao5/04_testes.sql
docker exec bd2_postgres psql -U bd2 -d chinook -c "SELECT count(*) FROM invoice WHERE invoice_id IN (99001, 99002);"
```
Expected: mesmo relatório; `count` = 0.

- [ ] **Step 4: Commit**

```bash
git add parte1/questao5/04_testes.sql
git commit -m "test(questao5): cenário de teste do DTE invoice_status"
```

---

### Task 5: READMEs

**Files:**
- Create: `parte1/questao5/README.md`
- Modify: `README.md` (raiz, seção "Estrutura do repositório", ~linha 98-103)

- [ ] **Step 1: Escrever `parte1/questao5/README.md`**

```markdown
# Questão 5 — Validação de DTE (Diagrama de Transição de Estados)

Solução genérica, dirigida por metadados, para validar os valores e as
transições de qualquer coluna de estado:

| Arquivo | Papel |
|---|---|
| `01_metadados.sql` | Tabelas que guardam o diagrama como dados (`dte_maquina`, `dte_estado`, `dte_transicao`) |
| `02_engine.sql` | Função de trigger genérica `fn_dte_validar(maquina, coluna)` |
| `03_cenario_invoice.sql` | Demonstração: coluna `status` na tabela `invoice` do Chinook |
| `04_testes.sql` | Cenário de teste com relatório `[OK]` / `[ERRO ESPERADO]` |

Os arquivos 01 e 02 são a solução reutilizável (não dependem do Chinook);
03 e 04 são a demonstração exigida pela questão.

## Como rodar (na raiz do projeto)

```bash
docker exec -i bd2_postgres psql -U bd2 -d chinook -v ON_ERROR_STOP=1 < parte1/questao5/01_metadados.sql
docker exec -i bd2_postgres psql -U bd2 -d chinook -v ON_ERROR_STOP=1 < parte1/questao5/02_engine.sql
docker exec -i bd2_postgres psql -U bd2 -d chinook -v ON_ERROR_STOP=1 < parte1/questao5/03_cenario_invoice.sql
docker exec -i bd2_postgres psql -U bd2 -d chinook < parte1/questao5/04_testes.sql
```

Todos os scripts são re-rodáveis. O teste limpa as linhas que cria.

## O diagrama usado na demonstração

```
PENDENTE ──> PAGA ──> ENVIADA ──> REEMBOLSADA (final)
   │            └────────────────────^
   └──────> CANCELADA (final)
```

## Como reutilizar em outra tabela/coluna

1. Inserir a máquina, estados e transições nas tabelas `dte_*` (só dados).
2. Criar a trigger na tabela alvo:

```sql
CREATE TRIGGER trg_dte_minha_tabela
    BEFORE INSERT OR UPDATE ON minha_tabela
    FOR EACH ROW
    EXECUTE FUNCTION fn_dte_validar('nome_da_maquina', 'nome_da_coluna');
```
```

- [ ] **Step 2: Atualizar a árvore no `README.md` da raiz**

Na seção "Estrutura do repositório", trocar:

```
│   ├── questao3.sql
│   ├── questao4.sql
```

por:

```
│   ├── questao3.sql
│   ├── questao4.sql
│   └── questao5/                   # validação genérica de DTE (metadados + trigger)
```

- [ ] **Step 3: Commit**

```bash
git add parte1/questao5/README.md README.md
git commit -m "docs(questao5): README da questão e estrutura no README raiz"
```

---

### Task 6: Verificação fim-a-fim do zero

**Files:** nenhum (verificação final).

- [ ] **Step 1: Rodar a sequência completa exatamente como o professor rodaria**

```bash
docker exec -i bd2_postgres psql -U bd2 -d chinook -v ON_ERROR_STOP=1 < parte1/questao5/01_metadados.sql
docker exec -i bd2_postgres psql -U bd2 -d chinook -v ON_ERROR_STOP=1 < parte1/questao5/02_engine.sql
docker exec -i bd2_postgres psql -U bd2 -d chinook -v ON_ERROR_STOP=1 < parte1/questao5/03_cenario_invoice.sql
docker exec -i bd2_postgres psql -U bd2 -d chinook < parte1/questao5/04_testes.sql
```
Expected: zero erros; relatório final sem nenhum `[FALHA]`.

- [ ] **Step 2: Conferir que nada vazou para as tabelas do Chinook**

```bash
docker exec bd2_postgres psql -U bd2 -d chinook -c "SELECT count(*) FROM invoice WHERE invoice_id >= 99000;"
```
Expected: `0`.

---

## Self-Review (executado na escrita do plano)

- **Spec coverage:** metadados (Task 1), engine genérica com TG_ARGV/row_to_json/regras INSERT/UPDATE/NULL (Task 2), cenário Invoice com estados e transições do spec (Task 3), testes [OK]/[ERRO ESPERADO] cobrindo os 6 casos do spec + 2 extras (UPDATE sem mudança de estado, NULL) (Task 4), README (Task 5). Sem lacunas.
- **Placeholders:** nenhum — todos os passos têm código completo e comandos exatos.
- **Consistência de nomes:** `fn_dte_validar`, `dte_maquina/dte_estado/dte_transicao`, `invoice_status`, `status`, `trg_dte_invoice` usados de forma idêntica nas Tasks 1-5.
- **Divergência consciente do spec:** o caso "transição inexistente" usa `PAGA -> CANCELADA` em vez de `PENDENTE -> ENVIADA` (a linha 99001 já está em PAGA no momento do teste — mantém o fluxo do cenário linear); a intenção do spec (testar seta inexistente) está coberta.
