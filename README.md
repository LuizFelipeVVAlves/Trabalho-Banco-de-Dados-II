# Trabalho-Banco-de-Dados-II

Trabalho desenvolvido para a matéria de Banco de Dados II da Universidade Federal Fluminense (UFF).

SGBD escolhido: **PostgreSQL 16**. Esquema de exemplo: **Chinook Database** (https://github.com/lerocha/chinook-database).

> Nota sobre nomenclatura: a versão atual do script Chinook (v1.4.5) usa `snake_case`
> minúsculo (`invoice_line`, `unit_price`, `quantity`, `total`). A especificação do
> trabalho referencia os nomes clássicos em PascalCase (`InvoiceLine`, `UnitPrice`...).
> São equivalentes em conteúdo — os scripts deste repositório usam `snake_case`.

## Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) com Docker Compose (já incluso no Docker Desktop).

## Subindo a infraestrutura

Na raiz do projeto:

```bash
docker compose up -d
```

Isso sobe um container `bd2_postgres` (PostgreSQL 16) com um volume persistente (`pgdata`).

### Carregando o Chinook

O script do Chinook fica em [`initdb/01_chinook.sql`](initdb/01_chinook.sql) e roda
**automaticamente na primeira inicialização** do banco (quando o volume `pgdata` ainda
não existe). Ele cria um database próprio chamado `chinook` e popula as tabelas.

Se o banco já existia e você precisa (re)carregar o Chinook manualmente:

```bash
docker exec -i bd2_postgres psql -U bd2 -d bd2 -v ON_ERROR_STOP=1 < initdb/01_chinook.sql
```

Para começar do zero (apaga TODOS os dados e recarrega o Chinook na subida):

```bash
docker compose down -v
docker compose up -d
```

## Conexão

| Parâmetro | Valor                          |
|-----------|--------------------------------|
| Host      | `localhost`                    |
| Porta     | `5432`                         |
| Database  | **`chinook`** (esquema do trabalho) |
| Usuário   | `bd2`                          |
| Senha     | `bd2`                          |

> As credenciais são triviais por ser ambiente local de estudo. Não use este compose
> como base para um ambiente exposto sem trocar usuário/senha (de preferência via `.env`).

## Rodando as consultas

### Pelo psql (linha de comando)

```bash
# Sessão interativa no database do trabalho
docker exec -it bd2_postgres psql -U bd2 -d chinook

# Rodar um arquivo .sql específico
docker exec -i bd2_postgres psql -U bd2 -d chinook < parte1/questao4.sql
```

Comandos úteis dentro do `psql`: `\dt` (lista tabelas), `\d nome_tabela` (descreve
tabela), `\di` (lista índices), `\q` (sair).

### Pelo VS Code

Instale a extensão **PostgreSQL (Microsoft)** ou **SQLTools + driver PostgreSQL**,
crie uma conexão com os dados da tabela acima e execute os `.sql` direto do editor,
visualizando o resultado em grade.

## Comandos úteis

```bash
docker compose up -d          # subir
docker compose ps             # status do container
docker compose logs -f        # acompanhar logs
docker compose stop           # parar (mantém os dados)
docker compose start          # religar
docker compose down           # remover container (mantém os dados no volume)
docker compose down -v        # remover container E apagar os dados do volume
```

## Estrutura do repositório

```
.
├── docker-compose.yml              # infraestrutura (PostgreSQL 16)
├── initdb/                         # scripts rodados na 1ª inicialização do banco
│   └── 01_chinook.sql              # esquema + dados do Chinook
├── parte1/                         # questões da Parte 1 (catálogo e programação no SGBD)
│   ├── questao1.sql
│   ├── questao2.sql
│   ├── questao3.sql
│   ├── questao4.sql
│   └── questao5/                   # validação genérica de DTE (metadados + trigger)
└── parte2/                         # questões da Parte 2 (regras semânticas)
```
