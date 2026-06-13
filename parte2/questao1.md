# Questão 1 – Regras Semânticas

## Regra 1 – Limite de faturas pendentes por cliente

Um cliente não pode possuir mais de 5 faturas simultaneamente no estado **PENDENTE**.

### Justificativa

Essa regra representa uma política de negócio para evitar o acúmulo excessivo de débitos por um mesmo cliente. Ela não pode ser garantida apenas pela estrutura relacional do banco de dados, pois depende da contagem dinâmica de registros associados a cada cliente.

### Exemplo válido

* Cliente possui 5 faturas pendentes.
* Uma das faturas é paga ou cancelada.
* Uma nova fatura pendente pode ser criada.

### Exemplo inválido

* Cliente já possui 5 faturas pendentes.
* Tentativa de criação de uma sexta fatura pendente.

---

## Regra 2 – Integridade do fluxo de estados de uma fatura

Uma fatura deve obedecer ao seguinte fluxo de estados:

```text
PENDENTE ──┬──> PAGA ──> ENVIADA ──> REEMBOLSADA
           │
           └──> CANCELADA
```

Qualquer transição diferente das especificadas acima deve ser considerada inválida.

### Justificativa

A regra garante a consistência do ciclo de vida de uma fatura, impedindo alterações arbitrárias de estado e assegurando que os processos de negócio ocorram na ordem correta.

### Exemplos válidos

* PENDENTE → PAGA
* PENDENTE → CANCELADA
* PAGA → ENVIADA
* ENVIADA → REEMBOLSADA

### Exemplos inválidos

* PENDENTE → ENVIADA
* CANCELADA → PAGA
* REEMBOLSADA → PENDENTE

---

## Regra 3 – Consistência do valor total da fatura

O valor armazenado na coluna `invoice.total` deve ser exatamente igual à soma dos produtos entre `unit_price` e `quantity` de todos os registros da tabela `invoice_line` associados à mesma fatura.

### Justificativa

A coluna `invoice.total` armazena uma informação redundante em relação aos dados presentes na tabela `invoice_line`. Portanto, é necessário garantir que o valor permaneça consistente após inserções, alterações ou remoções de itens da fatura.

### Exemplo válido

Fatura contendo:

| Unit Price | Quantity | Subtotal |
| ---------- | -------- | -------- |
| 0.99       | 2        | 1.98     |
| 1.99       | 3        | 5.97     |

Total da fatura = 7.95

### Exemplo inválido

Fatura contendo os mesmos itens acima e valor armazenado em `invoice.total = 8.50`.
