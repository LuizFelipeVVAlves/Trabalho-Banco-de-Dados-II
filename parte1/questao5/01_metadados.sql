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
