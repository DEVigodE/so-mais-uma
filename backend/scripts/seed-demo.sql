-- Carga de demonstração do "Só mais uma". Fica FORA das migrações (plataforma-backend):
-- aplique manualmente depois que a aplicação subir e o Flyway criar o esquema.
--
--   psql "$DB_URL_PSQL" -f scripts/seed-demo.sql
--   docker exec -i backend-postgres-1 psql -U somaisuma -d somaisuma < scripts/seed-demo.sql
--
-- Contas (senha de ambas: Senha123):
--   dono@demo.com     perfil DONO
--   cliente@demo.com  perfil CLIENTE
--
-- As datas das reservas são relativas ao dia em que o script roda. O script não faz nada se o
-- dono de demonstração já existir, então pode ser executado de novo sem duplicar dados.

DO $$
DECLARE
    hash_senha CONSTANT TEXT := '$2a$10$bEFqpRMCvlh1JLxKxefM7OjBtIHZlTJswTX.f8GlhgY7ZqNVThvwG';
    fuso       CONSTANT TEXT := 'America/Sao_Paulo';
    v_dono     BIGINT;
    v_cliente  BIGINT;
    v_savassi  BIGINT;
    v_pampulha BIGINT;
    v_lourdes  BIGINT;
    v_reserva  BIGINT;
    v_inicio   TIMESTAMPTZ;
    dia        SMALLINT;
BEGIN
    IF EXISTS (SELECT 1 FROM usuario WHERE email = 'dono@demo.com') THEN
        RAISE NOTICE 'Carga de demonstração já aplicada; nada a fazer.';
        RETURN;
    END IF;

    INSERT INTO usuario (nome, email, senha_hash, telefone, perfil)
    VALUES ('Dono Demo', 'dono@demo.com', hash_senha, '31988880000', 'DONO')
    RETURNING id INTO v_dono;

    INSERT INTO usuario (nome, email, senha_hash, telefone, perfil)
    VALUES ('Cliente Demo', 'cliente@demo.com', hash_senha, '31999990000', 'CLIENTE')
    RETURNING id INTO v_cliente;

    INSERT INTO quadra (dono_id, nome, tipo_esporte, descricao, preco_hora, cep, logradouro, numero, bairro,
                        cidade, uf, latitude, longitude)
    VALUES (v_dono, 'Arena Society Savassi', 'FUTEBOL_SOCIETY', 'Grama sintética, vestiário e estacionamento.',
            80.00, '30130151', 'Rua Pernambuco', '1000', 'Savassi', 'Belo Horizonte', 'MG', -19.935900, -43.933300)
    RETURNING id INTO v_savassi;

    INSERT INTO quadra (dono_id, nome, tipo_esporte, descricao, preco_hora, cep, logradouro, numero, bairro,
                        cidade, uf, latitude, longitude)
    VALUES (v_dono, 'Beach Tennis Pampulha', 'BEACH_TENNIS', 'Duas quadras de areia com iluminação.',
            120.00, '31270901', 'Avenida Otacílio Negrão de Lima', '6000', 'Pampulha', 'Belo Horizonte', 'MG',
            -19.851200, -43.973900)
    RETURNING id INTO v_pampulha;

    INSERT INTO quadra (dono_id, nome, tipo_esporte, descricao, preco_hora, cep, logradouro, numero, bairro,
                        cidade, uf, latitude, longitude)
    VALUES (v_dono, 'Ginásio Lourdes Futsal', 'FUTSAL', 'Piso de madeira, arquibancada.',
            95.00, '30170050', 'Rua da Bahia', '1500', 'Lourdes', 'Belo Horizonte', 'MG', -19.929300, -43.941800)
    RETURNING id INTO v_lourdes;

    -- Savassi e Lourdes abrem todos os dias 08:00–22:00; Pampulha só de segunda a sexta 16:00–23:00.
    FOR dia IN 1..7 LOOP
        INSERT INTO horario_funcionamento (quadra_id, dia_semana, hora_abertura, hora_fechamento)
        VALUES (v_savassi, dia, '08:00', '22:00'), (v_lourdes, dia, '08:00', '22:00');
        IF dia <= 5 THEN
            INSERT INTO horario_funcionamento (quadra_id, dia_semana, hora_abertura, hora_fechamento)
            VALUES (v_pampulha, dia, '16:00', '23:00');
        END IF;
    END LOOP;

    -- Reserva CONFIRMADA amanhã às 19:00 na Savassi, com cobrança paga.
    v_inicio := (((now() AT TIME ZONE fuso)::date + 1) + TIME '19:00') AT TIME ZONE fuso;
    INSERT INTO reserva (quadra_id, cliente_id, inicio, fim, valor, status, observacao, expira_em)
    VALUES (v_savassi, v_cliente, v_inicio, v_inicio + INTERVAL '60 minutes', 80.00, 'CONFIRMADA',
            'Levamos as bolas', now() + INTERVAL '15 minutes')
    RETURNING id INTO v_reserva;
    INSERT INTO pagamento (reserva_id, txid, provedor, valor, status, pix_copia_e_cola, end_to_end_id,
                           expira_em, pago_em)
    VALUES (v_reserva, 'd3m0c0nf1rm4d4000000000000000001', 'SIMULADO', 80.00, 'PAGO',
            '00020126430014br.gov.bcb.pix0121somaisuma@exemplo.com520400005303986540580.005802BR5911SO MAIS UMA6014BELO HORIZONTE62290525d3m0c0nf1rm4d4000000000006304CAAA',
            'SIMDEMO0000000000000000000000001', now() + INTERVAL '15 minutes', now());

    -- Reserva EXPIRADA ontem às 10:00 no Lourdes, com cobrança expirada.
    v_inicio := (((now() AT TIME ZONE fuso)::date - 1) + TIME '10:00') AT TIME ZONE fuso;
    INSERT INTO reserva (quadra_id, cliente_id, inicio, fim, valor, status, expira_em)
    VALUES (v_lourdes, v_cliente, v_inicio, v_inicio + INTERVAL '60 minutes', 95.00, 'EXPIRADA',
            now() - INTERVAL '2 days')
    RETURNING id INTO v_reserva;
    INSERT INTO pagamento (reserva_id, txid, provedor, valor, status, pix_copia_e_cola, expira_em)
    VALUES (v_reserva, 'd3m0exp1r4d4000000000000000000002', 'SIMULADO', 95.00, 'EXPIRADO',
            '00020126430014br.gov.bcb.pix0121somaisuma@exemplo.com520400005303986540595.005802BR5911SO MAIS UMA6014BELO HORIZONTE62290525d3m0exp1r4d400000000000006304D020',
            now() - INTERVAL '2 days');

    RAISE NOTICE 'Carga de demonstração aplicada: dono %, cliente %, quadras %, %, %',
        v_dono, v_cliente, v_savassi, v_pampulha, v_lourdes;
END
$$;
