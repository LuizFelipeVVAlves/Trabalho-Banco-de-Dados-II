SELECT
    	tabelas.relname AS nome_tabela,
    	indices.relname AS nome_indice,
    	colunas.attname AS nome_coluna
FROM
    	pg_class tabelas
JOIN
    	pg_index ponte ON tabelas.oid = ponte.indrelid
JOIN
    	pg_class indices ON indices.oid = ponte.indexrelid
JOIN
    	pg_attribute colunas ON colunas.attrelid = tabelas.oid AND colunas.attnum = ANY(ponte.indkey)
WHERE
    	tabelas.relkind = 'r' AND tabelas.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
ORDER BY
   	tabelas.relname,
    	indices.relname;