-- Adicionar colunas de contato e localização à tabela users
ALTER TABLE users
ADD COLUMN IF NOT EXISTS city text,
ADD COLUMN IF NOT EXISTS state varchar(2),
ADD COLUMN IF NOT EXISTS phone text;
