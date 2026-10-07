-- Esquema inicial do backend "Só mais uma" (design.md D9).
-- CONGELADO após a tag v0.1-n1: toda evolução entra como V2, V3... sempre aditiva.

CREATE TABLE usuario (
    id             BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome           VARCHAR(100) NOT NULL,
    email          VARCHAR(150) NOT NULL,
    senha_hash     VARCHAR(72)  NOT NULL,
    telefone       VARCHAR(20),
    perfil         VARCHAR(10)  NOT NULL,
    ativo          BOOLEAN      NOT NULL DEFAULT TRUE,
    criado_em      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    atualizado_em  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_usuario_perfil          CHECK (perfil IN ('CLIENTE', 'DONO')),
    CONSTRAINT ck_usuario_email_minusculo CHECK (email = lower(email))
);
CREATE UNIQUE INDEX ux_usuario_email ON usuario (email);

CREATE TABLE quadra (
    id             BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dono_id        BIGINT        NOT NULL REFERENCES usuario (id),
    nome           VARCHAR(100)  NOT NULL,
    tipo_esporte   VARCHAR(20)   NOT NULL,
    descricao      VARCHAR(500),
    preco_hora     NUMERIC(10,2) NOT NULL,
    cep            CHAR(8)       NOT NULL,
    logradouro     VARCHAR(150)  NOT NULL,
    numero         VARCHAR(10)   NOT NULL,
    bairro         VARCHAR(80),
    cidade         VARCHAR(80)   NOT NULL,
    uf             CHAR(2)       NOT NULL,
    latitude       NUMERIC(9,6),
    longitude      NUMERIC(9,6),
    foto_url       VARCHAR(300),
    ativa          BOOLEAN       NOT NULL DEFAULT TRUE,
    criado_em      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_quadra_tipo_esporte CHECK (tipo_esporte IN
        ('FUTEBOL_SOCIETY', 'FUTSAL', 'VOLEI', 'BASQUETE', 'TENIS', 'BEACH_TENNIS', 'PADEL')),
    CONSTRAINT ck_quadra_preco_hora   CHECK (preco_hora > 0),
    CONSTRAINT ck_quadra_cep          CHECK (cep ~ '^[0-9]{8}$'),
    CONSTRAINT ck_quadra_uf           CHECK (uf = upper(uf)),
    CONSTRAINT ck_quadra_latitude     CHECK (latitude  IS NULL OR latitude  BETWEEN  -90 AND  90),
    CONSTRAINT ck_quadra_longitude    CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    CONSTRAINT ck_quadra_coordenadas  CHECK ((latitude IS NULL) = (longitude IS NULL))
);
CREATE INDEX idx_quadra_dono ON quadra (dono_id);

CREATE TABLE horario_funcionamento (
    id               BIGINT   GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    quadra_id        BIGINT   NOT NULL REFERENCES quadra (id) ON DELETE CASCADE,
    dia_semana       SMALLINT NOT NULL,
    hora_abertura    TIME     NOT NULL,
    hora_fechamento  TIME     NOT NULL,
    CONSTRAINT ck_horario_dia_semana  CHECK (dia_semana BETWEEN 1 AND 7),
    CONSTRAINT ck_horario_intervalo   CHECK (hora_fechamento > hora_abertura),
    CONSTRAINT ck_horario_hora_cheia  CHECK (EXTRACT(MINUTE FROM hora_abertura) = 0
                                         AND EXTRACT(MINUTE FROM hora_fechamento) = 0),
    CONSTRAINT ux_horario_quadra_dia  UNIQUE (quadra_id, dia_semana)
);

CREATE TABLE reserva (
    id                   BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    quadra_id            BIGINT        NOT NULL REFERENCES quadra (id),
    cliente_id           BIGINT        NOT NULL REFERENCES usuario (id),
    inicio               TIMESTAMPTZ   NOT NULL,
    fim                  TIMESTAMPTZ   NOT NULL,
    valor                NUMERIC(10,2) NOT NULL,
    status               VARCHAR(20)   NOT NULL,
    observacao           VARCHAR(200),
    expira_em            TIMESTAMPTZ   NOT NULL,
    cancelado_por        VARCHAR(10),
    motivo_cancelamento  VARCHAR(200),
    cancelado_em         TIMESTAMPTZ,
    criado_em            TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_reserva_status        CHECK (status IN
        ('PENDENTE_PAGAMENTO', 'CONFIRMADA', 'CANCELADA', 'EXPIRADA')),
    CONSTRAINT ck_reserva_valor         CHECK (valor > 0),
    CONSTRAINT ck_reserva_duracao       CHECK (fim = inicio + INTERVAL '60 minutes'),
    CONSTRAINT ck_reserva_hora_cheia    CHECK (inicio = date_trunc('hour', inicio AT TIME ZONE INTERVAL '-03:00')
                                                              AT TIME ZONE INTERVAL '-03:00'),
    CONSTRAINT ck_reserva_cancelado_por CHECK (cancelado_por IS NULL OR cancelado_por IN ('CLIENTE', 'DONO', 'SISTEMA')),
    CONSTRAINT ck_reserva_cancelamento  CHECK ((status = 'CANCELADA') = (cancelado_por IS NOT NULL))
);
CREATE INDEX idx_reserva_cliente         ON reserva (cliente_id, inicio DESC);
CREATE INDEX idx_reserva_quadra_inicio   ON reserva (quadra_id, inicio);
CREATE INDEX idx_reserva_pendente_expira ON reserva (expira_em) WHERE status = 'PENDENTE_PAGAMENTO';

CREATE UNIQUE INDEX ux_reserva_slot_ativo ON reserva (quadra_id, inicio)
    WHERE status IN ('PENDENTE_PAGAMENTO', 'CONFIRMADA');

CREATE TABLE pagamento (
    id                BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reserva_id        BIGINT        NOT NULL REFERENCES reserva (id),
    txid              VARCHAR(35)   NOT NULL,
    provedor          VARCHAR(10)   NOT NULL,
    valor             NUMERIC(10,2) NOT NULL,
    status            VARCHAR(10)   NOT NULL,
    pix_copia_e_cola  TEXT          NOT NULL,
    location          VARCHAR(255),
    end_to_end_id     VARCHAR(32),
    expira_em         TIMESTAMPTZ   NOT NULL,
    pago_em           TIMESTAMPTZ,
    criado_em         TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ux_pagamento_reserva  UNIQUE (reserva_id),
    CONSTRAINT ux_pagamento_txid     UNIQUE (txid),
    CONSTRAINT ck_pagamento_txid     CHECK (txid ~ '^[A-Za-z0-9]{26,35}$'),
    CONSTRAINT ck_pagamento_provedor CHECK (provedor IN ('INTER', 'SIMULADO')),
    CONSTRAINT ck_pagamento_status   CHECK (status IN ('PENDENTE', 'PAGO', 'EXPIRADO', 'CANCELADO')),
    CONSTRAINT ck_pagamento_valor    CHECK (valor > 0),
    CONSTRAINT ck_pagamento_pago     CHECK ((status = 'PAGO') = (pago_em IS NOT NULL))
);
CREATE UNIQUE INDEX ux_pagamento_end_to_end ON pagamento (end_to_end_id) WHERE end_to_end_id IS NOT NULL;
CREATE INDEX idx_pagamento_pendente ON pagamento (criado_em) WHERE status = 'PENDENTE';
