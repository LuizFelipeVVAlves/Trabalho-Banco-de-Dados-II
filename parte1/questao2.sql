CREATE OR REPLACE PROCEDURE remover_indices_tabela(p_nome_tabela VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
    -- Aqui criamos uma variável para guardar temporariamente o nome de cada índice que encontrarmos
    registro_indice RECORD; 
BEGIN
    -- Vamos fazer um "Loop" (repetição). Ele vai buscar os índices usando a mesma lógica da Questão 1.
    FOR registro_indice IN 
        SELECT indices.relname AS nome_indice
        FROM pg_class tabelas
        JOIN pg_index ponte ON tabelas.oid = ponte.indrelid
        JOIN pg_class indices ON indices.oid = ponte.indexrelid
        WHERE tabelas.relname = p_nome_tabela -- Aqui nós filtramos pela tabela que o usuário digitou!
          AND tabelas.relkind = 'r'
          AND ponte.indisprimary = false -- Regra de ouro: Não apagamos a Chave Primária para não quebrar a tabela!
    LOOP
        -- Para cada índice que ele achar, ele monta o comando "DROP INDEX nome_do_indice" e executa.
        EXECUTE 'DROP INDEX ' || quote_ident(registro_indice.nome_indice);

        -- Manda uma mensagem avisando que apagou
        RAISE NOTICE 'O índice % foi apagado com sucesso!', registro_indice.nome_indice;
    END LOOP;
END;
$$;