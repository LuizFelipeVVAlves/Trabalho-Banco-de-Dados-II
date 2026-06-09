# Questão 5 — Validação de DTE genérica (Parte 1)

Data: 2026-06-09
SGBD: PostgreSQL (Chinook Database)

## Objetivo

Implementar, via programação em banco de dados, uma solução para validar os
valores de uma coluna que representa uma situação (estado), garantindo que tanto
os **valores** quanto as **transições** atendam a especificação de um Diagrama de
Transição de Estados (DTE). A solução deve ser o mais genérica e reutilizável
possível, acompanhada de um cenário de teste.

## Decisões de design

- **Definição do DTE como metadados** (não como código): o diagrama é armazenado
  em dados. Adicionar um novo DTE = inserir linhas, sem escrever código novo.
- **Trigger genérica única**: uma função de trigger serve qualquer tabela/coluna,
  parametrizada via `TG_ARGV`.
- **Cenário de teste**: `ALTER TABLE invoice` adicionando coluna de status (tabela
  real do Chinook), demonstrando reuso sobre dados existentes.
- **NULL** rejeitado por padrão.

## Arquitetura

```
dte_maquina ──< dte_estado
      └────────< dte_transicao
                      ▲
   fn_dte_validar()  (trigger genérica, anexada por tabela)
```

### Tabelas de metadados

- `dte_maquina(maquina_id PK, nome UNIQUE, descricao)` — uma linha por DTE.
- `dte_estado(maquina_id FK, estado, is_inicial bool, is_final bool,
  PK(maquina_id, estado))` — estados válidos; marca quais podem ser iniciais.
- `dte_transicao(maquina_id FK, estado_origem, estado_destino,
  PK(maquina_id, estado_origem, estado_destino))` — cada linha é uma seta
  permitida; FKs para `dte_estado` garantem integridade origem/destino.

### Engine — `fn_dte_validar()`

Função PL/pgSQL única, reutilizável. Recebe via `TG_ARGV`:
1. nome da máquina (ex.: `'invoice_status'`)
2. nome da coluna de estado (ex.: `'status'`)

Lê o valor da coluna dinamicamente via `row_to_json(NEW)->>coluna`.

Regras:
- **INSERT**: valor precisa existir em `dte_estado` da máquina **e** ter
  `is_inicial = true`. Senão `RAISE EXCEPTION`.
- **UPDATE**:
  - estado inalterado → permite.
  - estado alterado → exige linha em `dte_transicao(origem=OLD, destino=NEW)`.
    Senão exceção: `"Transição inválida: X → Y na máquina Z"`.
- **NULL**: rejeitado.

Anexação a uma tabela (uma linha):
```sql
CREATE TRIGGER trg_dte_invoice
  BEFORE INSERT OR UPDATE ON invoice
  FOR EACH ROW EXECUTE FUNCTION fn_dte_validar('invoice_status', 'status');
```

## Cenário de teste (Invoice)

- `ALTER TABLE invoice ADD COLUMN status ... DEFAULT 'PENDENTE'`.
- DTE `invoice_status`:
  - Estados: `PENDENTE` (inicial), `PAGA`, `ENVIADA`, `CANCELADA` (final),
    `REEMBOLSADA` (final).
  - Transições: `PENDENTE→PAGA`, `PENDENTE→CANCELADA`, `PAGA→ENVIADA`,
    `PAGA→REEMBOLSADA`, `ENVIADA→REEMBOLSADA`.
- Casos de teste (cada erro em `BEGIN/EXCEPTION` para o script rodar inteiro,
  com `RAISE NOTICE` em texto puro `[OK]` / `[ERRO ESPERADO]` — sem emojis, para
  compatibilidade com terminais Windows):
  1. [OK] INSERT `PENDENTE` (inicial válido)
  2. [ERRO ESPERADO] INSERT `PAGA` (não é inicial)
  3. [OK] UPDATE `PENDENTE→PAGA`
  4. [ERRO ESPERADO] UPDATE `PENDENTE→ENVIADA` (transição inexistente)
  5. [OK] UPDATE `PAGA→ENVIADA`
  6. [ERRO ESPERADO] UPDATE `CANCELADA→PAGA` (saída de estado final)

## Estrutura de arquivos

```
parte1/questao5/
├── 01_metadados.sql        -- tabelas dte_maquina / dte_estado / dte_transicao
├── 02_engine.sql           -- função genérica fn_dte_validar()
├── 03_cenario_invoice.sql  -- ALTER invoice + popular DTE + anexar trigger
├── 04_testes.sql           -- cenário de teste com casos ✅/❌
└── README.md               -- ordem de execução e instruções
```

A engine (01 + 02) é a solução reutilizável; o cenário (03 + 04) é a demonstração
no Chinook, independente da estrutura do Invoice.
