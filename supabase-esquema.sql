-- Ejecutar esto en Supabase: SQL Editor > New query > pegar > Run

create table empresas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  codigo_invitacion text not null unique,
  creada_en timestamptz default now()
);

create table usuarios (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  contrasena_hash text not null,
  empresa_id uuid not null references empresas(id) on delete cascade,
  rol text not null check (rol in ('admin', 'empleado')),
  creado_en timestamptz default now()
);

-- Índice para buscar rápido por email al hacer login
create index idx_usuarios_email on usuarios(email);
