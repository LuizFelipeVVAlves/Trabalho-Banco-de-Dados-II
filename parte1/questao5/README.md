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

> Escopo: a validação cobre INSERT e UPDATE. DELETE fica fora do DTE por
> decisão de projeto — remover uma linha encerra o ciclo de vida dela, não
> é uma transição de estado.
