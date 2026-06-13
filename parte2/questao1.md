# Questão 1 – Regras Semânticas

## Regra 1 – Não permitir faturas duplicadas para um mesmo cliente

Um cliente não pode possuir duas faturas com a mesma data (`invoice_date`) e o mesmo valor total (`total`).

### Justificativa

Embora o banco permita a existência de múltiplas faturas para um mesmo cliente, a ocorrência simultânea de faturas com a mesma data e o mesmo valor pode indicar duplicidade de lançamento. Essa restrição depende da análise conjunta de múltiplos registros e, portanto, não pode ser garantida apenas por chaves primárias, estrangeiras ou restrições de domínio.

### Exemplo válido

| CustomerId | InvoiceDate | Total |
| ---------- | ----------- | ----- |
| 1          | 2025-01-10  | 10.99 |
| 1          | 2025-01-11  | 10.99 |

### Exemplo inválido

| CustomerId | InvoiceDate | Total |
| ---------- | ----------- | ----- |
| 1          | 2025-01-10  | 10.99 |
| 1          | 2025-01-10  | 10.99 |

---

## Regra 2 – Não permitir músicas repetidas na mesma fatura

Uma mesma música (`track_id`) não pode aparecer mais de uma vez na mesma fatura (`invoice_id`).

### Justificativa

Cada item da tabela `invoice_line` representa a venda de uma música. Permitir que a mesma música apareça repetidamente na mesma fatura pode gerar inconsistências ou duplicidade de cobrança. Essa regra depende da verificação dos registros já existentes na tabela e não pode ser garantida apenas pela estrutura relacional atual.

### Exemplo válido

| InvoiceId | TrackId |
| --------- | ------- |
| 10        | 5       |
| 10        | 8       |

### Exemplo inválido

| InvoiceId | TrackId |
| --------- | ------- |
| 10        | 5       |
| 10        | 5       |

---

## Regra 3 – Consistência do valor total da fatura

O valor armazenado na coluna `invoice.total` deve ser exatamente igual à soma dos produtos entre `unit_price` e `quantity` de todos os registros da tabela `invoice_line` pertencentes à mesma fatura.

### Justificativa

A coluna `invoice.total` armazena uma informação redundante em relação aos dados presentes em `invoice_line`. Para garantir a integridade dos dados, o valor total da fatura deve ser mantido consistente sempre que houver inserções, alterações ou exclusões de itens.

### Exemplo válido

| UnitPrice | Quantity | Subtotal |
| --------- | -------- | -------- |
| 0.99      | 2        | 1.98     |
| 1.99      | 3        | 5.97     |

Total da fatura = 7.95

### Exemplo inválido

Mesmos itens acima, porém:

```text
invoice.total = 8.50
```

Nesse caso, o valor armazenado na fatura não corresponde à soma de seus itens.
