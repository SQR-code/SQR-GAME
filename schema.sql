-- Square Off: database setup for online play.
-- Paste this whole file into Supabase > SQL Editor > New query, then press Run.
-- It's safe to run more than once.

-- 1. The table that stores every online game
create table if not exists public.games (
  id         text primary key,                      -- the short code friends share, e.g. K7QXM
  black      uuid,                                  -- the player sitting at Black (empty until someone joins)
  white      uuid,                                  -- the player sitting at White
  moves      jsonb not null default '[]'::jsonb,    -- every move so far, in order
  version    integer not null default 0,            -- goes up by one with each move
  created_at timestamptz not null default now(),
  constraint creator_has_a_seat check (black is not null or white is not null)
);

-- 2. Access rules (Row Level Security)
alter table public.games enable row level security;

drop policy if exists "Anyone can view games" on public.games;
drop policy if exists "You can create a game you play in" on public.games;
drop policy if exists "Players can update; anyone can take an empty seat" on public.games;

create policy "Anyone can view games"
  on public.games for select
  using (true);

create policy "You can create a game you play in"
  on public.games for insert to authenticated
  with check (auth.uid() = black or auth.uid() = white);

create policy "Players can update; anyone can take an empty seat"
  on public.games for update to authenticated
  using (auth.uid() = black or auth.uid() = white or black is null or white is null)
  with check (auth.uid() = black or auth.uid() = white);

-- 3. Fair-play checks that run on the server for every update
create or replace function public.check_game_update() returns trigger
language plpgsql as $$
declare
  n integer := jsonb_array_length(old.moves);
begin
  if new.id <> old.id or new.created_at <> old.created_at then
    raise exception 'A game''s code can''t be changed';
  end if;
  if old.black is not null and new.black is distinct from old.black then
    raise exception 'The Black seat is already taken';
  end if;
  if old.white is not null and new.white is distinct from old.white then
    raise exception 'The White seat is already taken';
  end if;
  if new.moves is distinct from old.moves or new.version <> old.version then
    -- exactly one new move, added to the end, by the player whose turn it is
    if jsonb_array_length(new.moves) <> n + 1 or new.version <> old.version + 1 then
      raise exception 'Exactly one move can be added at a time';
    end if;
    if (new.moves - n) <> old.moves then
      raise exception 'Earlier moves can''t be changed';
    end if;
    if auth.uid() is distinct from (case when n % 2 = 0 then old.black else old.white end) then
      raise exception 'It isn''t your turn';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists check_game_update on public.games;
create trigger check_game_update
  before update on public.games
  for each row execute function public.check_game_update();

-- 4. Turn on live updates for this table, so moves appear instantly
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'games') then
    alter publication supabase_realtime add table public.games;
  end if;
end $$;
