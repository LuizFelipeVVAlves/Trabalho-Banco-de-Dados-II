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

## Regra 3 – Não permitir ciclos na hierarquia de funcionários

A estrutura hierárquica da empresa, representada pela coluna `reports_to` da tabela `employee`, não pode conter ciclos.

### Justificativa

A coluna `reports_to` indica o supervisor direto de cada funcionário. Embora a chave estrangeira existente garanta que o supervisor informado exista na tabela `employee`, ela não impede a criação de relacionamentos circulares.

A existência de ciclos compromete a integridade da hierarquia organizacional, tornando impossível determinar corretamente as relações de subordinação entre funcionários.

Essa restrição não pode ser garantida apenas pela estrutura relacional do banco de dados, exigindo validação adicional através de mecanismos de programação em banco de dados.

### Exemplo válido

| EmployeeId | ReportsTo |
| ---------- | --------- |
| 1          | NULL      |
| 2          | 1         |
| 3          | 2         |

Hierarquia:

```text
1
└── 2
    └── 3
```

### Exemplos inválidos

Funcionário supervisionando a si mesmo:

| EmployeeId | ReportsTo |
| ---------- | --------- |
| 1          | 1         |

Hierarquia circular:

| EmployeeId | ReportsTo |
| ---------- | --------- |
| 1          | 2         |
| 2          | 1         |

Hierarquia circular indireta:

| EmployeeId | ReportsTo |
| ---------- | --------- |
| 1          | 2         |
| 2          | 3         |
| 3          | 1         |

