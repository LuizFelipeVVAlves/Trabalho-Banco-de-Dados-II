CREATE OR REPLACE FUNCTION gerar_create_tables()
RETURNS TABLE (
    nome_tabela TEXT,
    comando_create TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        tabelas.relname::TEXT AS nome_tabela,

        'CREATE TABLE ' || quote_ident(tabelas.relname) || E' (\n' ||

        -- Aqui montamos as colunas da tabela
        (
            SELECT string_agg(
                '    ' || quote_ident(colunas.attname) || ' ' ||
                format_type(colunas.atttypid, colunas.atttypmod) ||
                CASE
                    WHEN colunas.attnotnull THEN ' NOT NULL'
                    ELSE ''
                END,
                E',\n'
                ORDER BY colunas.attnum
            )
            FROM pg_attribute colunas
            WHERE colunas.attrelid = tabelas.oid
              AND colunas.attnum > 0
              AND colunas.attisdropped = false
        ) ||

        -- Aqui adicionamos as chaves primárias e estrangeiras
        COALESCE(
            E',\n' ||
            (
                SELECT string_agg(
                    '    CONSTRAINT ' || quote_ident(restricoes.conname) || ' ' ||
                    pg_get_constraintdef(restricoes.oid),
                    E',\n'
                    ORDER BY restricoes.conname
                )
                FROM pg_constraint restricoes
                WHERE restricoes.conrelid = tabelas.oid
                  AND restricoes.contype IN ('p', 'f')
            ),
            ''
        ) ||

        E'\n);' AS comando_create

    FROM pg_class tabelas
    JOIN pg_namespace esquema ON esquema.oid = tabelas.relnamespace
    WHERE tabelas.relkind = 'r'
      AND esquema.nspname = 'public'
    ORDER BY tabelas.relname;
END;
$$;

SELECT *
FROM gerar_create_tables();