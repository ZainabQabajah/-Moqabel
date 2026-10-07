-- Run once in a NEW Supabase project's SQL editor. Never exposes service-role keys.
begin;
create table public.profiles (
 id uuid primary key references auth.users on delete cascade,
 display_name text not null check (char_length(display_name) between 1 and 60),
 city text not null default 'رام الله', created_at timestamptz not null default now()
);
create function public.on_signup() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into profiles(id,display_name) values(new.id,left(coalesce(nullif(new.raw_user_meta_data->>'display_name',''),'عضو مقابل'),60)); return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.on_signup();
create table public.items (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references profiles,
 title text not null check(char_length(title) between 3 and 100),
 description text not null check(char_length(description) between 10 and 2000),
 category text not null check(category in ('electronics','gaming','books')),
 wanted_categories text[] not null check(cardinality(wanted_categories) between 1 and 3 and wanted_categories <@ array['electronics','gaming','books']),
 wanted_text text not null check(char_length(wanted_text) between 3 and 200),
 city text not null check(char_length(city) between 2 and 60),
 condition text not null check(condition in ('جديد','كأنه جديد','جيد جدًا','جيد','بحاجة لصيانة')),
 image_url text not null check(char_length(image_url)<2048 and image_url like 'https://%'),
 status text not null default 'available' check(status in ('available','reserved','swapped')),
 created_at timestamptz not null default now()
);
create table public.offers (
 id uuid primary key default gen_random_uuid(), proposer_id uuid not null references profiles,
 recipient_id uuid not null references profiles, offered_item_id uuid not null references items,
 requested_item_id uuid not null references items,
 status text not null default 'pending' check(status in ('pending','accepted','declined','cancelled','completed','disputed')),
 proposer_confirmed boolean not null default false, recipient_confirmed boolean not null default false,
 proposer_code uuid not null default gen_random_uuid(), recipient_code uuid not null default gen_random_uuid(),
 meeting_note text not null default '' check(char_length(meeting_note)<=500),
 created_at timestamptz not null default now(), check(proposer_id<>recipient_id), check(offered_item_id<>requested_item_id)
);
create unique index unique_pending_offer on offers(offered_item_id,requested_item_id) where status in ('pending','accepted');
create table public.messages (
 id uuid primary key default gen_random_uuid(), offer_id uuid not null references offers on delete cascade,
 sender_id uuid not null references profiles, body text not null check(char_length(body) between 1 and 2000), created_at timestamptz not null default now()
);
create table public.favorites ( user_id uuid not null references profiles on delete cascade, item_id uuid not null references items on delete cascade, primary key(user_id,item_id));
create table public.reports (
 id uuid primary key default gen_random_uuid(), reporter_id uuid not null references profiles,
 item_id uuid references items, offer_id uuid references offers,
 reason text not null check(char_length(reason) between 10 and 2000), created_at timestamptz not null default now(),
 check ((item_id is not null)::int + (offer_id is not null)::int = 1)
);
create table public.ratings (
 offer_id uuid not null references offers, author_id uuid not null references profiles,
 stars int not null check(stars between 1 and 5), created_at timestamptz not null default now(), primary key(offer_id,author_id)
);
create index items_available on items(status,category,city);
create index offers_proposer on offers(proposer_id);
create index offers_recipient on offers(recipient_id);
create index messages_offer on messages(offer_id,created_at);
alter table profiles enable row level security;
alter table items enable row level security;
alter table offers enable row level security;
alter table messages enable row level security;
alter table favorites enable row level security;
alter table reports enable row level security;
alter table ratings enable row level security;
create policy public_profiles on profiles for select using (true);
create policy own_profile on profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy readable_items on items for select using(true);
create policy create_item on items for insert to authenticated with check(owner_id=auth.uid() and status='available');
create policy participants_read on offers for select to authenticated using(auth.uid() in (proposer_id,recipient_id));
create policy participants_messages on messages for select to authenticated using(exists(select 1 from offers o where o.id=offer_id and auth.uid() in(o.proposer_id,o.recipient_id)));
create policy send_message on messages for insert to authenticated with check(sender_id=auth.uid() and exists(select 1 from offers o where o.id=offer_id and auth.uid() in(o.proposer_id,o.recipient_id) and o.status in('pending','accepted','disputed')));
create policy own_favorites on favorites for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy own_reports on reports for select to authenticated using(reporter_id=auth.uid());
create policy report_item on reports for insert to authenticated with check(reporter_id=auth.uid() and item_id is not null and offer_id is null);
create policy ratings_read on ratings for select to authenticated using(exists(select 1 from offers o where o.id=offer_id and auth.uid() in(o.proposer_id,o.recipient_id)));
create policy rate_completed on ratings for insert to authenticated with check(author_id=auth.uid() and exists(select 1 from offers o where o.id=offer_id and o.status='completed' and auth.uid() in(o.proposer_id,o.recipient_id)));
-- Clients must not read the other party's handover secret.
revoke all on offers from anon, authenticated;
grant select(id,proposer_id,recipient_id,offered_item_id,requested_item_id,status,proposer_confirmed,recipient_confirmed,meeting_note,created_at) on offers to authenticated;
grant select on profiles,items to anon,authenticated;
grant insert on items to authenticated;
grant update(display_name,city) on profiles to authenticated;
grant select,insert on messages,reports,ratings to authenticated;
grant select,insert,delete on favorites to authenticated;
revoke update,delete on items from anon,authenticated;

create function public.create_offer(offered uuid, requested uuid) returns uuid language plpgsql security definer set search_path=public as $$
declare a items; b items; result uuid;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 -- Stable lock ordering prevents reverse offers from deadlocking.
 perform id from items where id in(offered,requested) order by id for update;
 select * into a from items where id=offered; select * into b from items where id=requested;
 if a.id is null or b.id is null or a.owner_id<>auth.uid() or b.owner_id=auth.uid() or a.status<>'available' or b.status<>'available' then raise exception 'Items unavailable'; end if;
 if exists(select 1 from offers where proposer_id=auth.uid() and created_at>now()-interval '1 hour' having count(*)>=20) then raise exception 'Offer limit reached'; end if;
 insert into offers(proposer_id,recipient_id,offered_item_id,requested_item_id) values(auth.uid(),b.owner_id,offered,requested) returning id into result;
 return result;
end; $$;

create function public.respond_offer(offer_uuid uuid, decision text) returns void language plpgsql security definer set search_path=public as $$
declare o offers;
begin
 -- Lock all item rows before offer rows; serialize competing accepts and confirmations.
 select * into o from offers where id=offer_uuid;
 if o.id is null or auth.uid() is null or auth.uid() not in(o.proposer_id,o.recipient_id) then raise exception 'Not authorized'; end if;
 perform id from items where id in(o.offered_item_id,o.requested_item_id) order by id for update;
 select * into o from offers where id=offer_uuid for update;
 if o.status<>'pending' then raise exception 'Offer is no longer pending'; end if;
 if decision in('accepted','declined') and auth.uid()<>o.recipient_id then raise exception 'Only recipient can respond'; end if;
 if decision='cancelled' and auth.uid()<>o.proposer_id then raise exception 'Only proposer can cancel'; end if;
 if decision is null or decision not in('accepted','declined','cancelled') then raise exception 'Invalid decision'; end if;
 if decision='accepted' then
  if exists(select 1 from items where id in(o.offered_item_id,o.requested_item_id) and status<>'available') then raise exception 'Items unavailable'; end if;
  update items set status='reserved' where id in(o.offered_item_id,o.requested_item_id);
  update offers set status='declined' where id<>o.id and status='pending' and (offered_item_id in(o.offered_item_id,o.requested_item_id) or requested_item_id in(o.offered_item_id,o.requested_item_id));
 end if;
 update offers set status=decision where id=o.id;
end; $$;

create function public.my_handover_code(offer_uuid uuid) returns text language plpgsql security definer set search_path=public as $$
declare o offers;
begin
 select * into o from offers where id=offer_uuid;
 if auth.uid() is null or o.id is null or auth.uid() not in(o.proposer_id,o.recipient_id) or o.status<>'accepted' then raise exception 'Not authorized'; end if;
 return case when auth.uid()=o.proposer_id then o.proposer_code::text else o.recipient_code::text end;
end; $$;

create function public.confirm_handover(offer_uuid uuid, partner_code text) returns void language plpgsql security definer set search_path=public as $$
declare o offers;
begin
 select * into o from offers where id=offer_uuid;
 if auth.uid() is null or o.id is null or auth.uid() not in(o.proposer_id,o.recipient_id) then raise exception 'Not authorized'; end if;
 perform id from items where id in(o.offered_item_id,o.requested_item_id) order by id for update;
 select * into o from offers where id=offer_uuid for update;
 if o.status<>'accepted' then raise exception 'Offer not accepted'; end if;
 if partner_code is null then raise exception 'Invalid handover code'; end if;
 if auth.uid()=o.proposer_id then
  if partner_code<>o.recipient_code::text then raise exception 'Invalid handover code'; end if;
  update offers set proposer_confirmed=true where id=o.id;
 else
  if partner_code<>o.proposer_code::text then raise exception 'Invalid handover code'; end if;
  update offers set recipient_confirmed=true where id=o.id;
 end if;
 if exists(select 1 from offers where id=o.id and proposer_confirmed and recipient_confirmed) then
  update offers set status='completed' where id=o.id;
  update items set status='swapped' where id in(o.offered_item_id,o.requested_item_id);
 end if;
end; $$;

create function public.report_swap(offer_uuid uuid, details text) returns void language plpgsql security definer set search_path=public as $$
declare o offers;
begin
 select * into o from offers where id=offer_uuid;
 if auth.uid() is null or o.id is null or auth.uid() not in(o.proposer_id,o.recipient_id) then raise exception 'Not authorized'; end if;
 perform id from items where id in(o.offered_item_id,o.requested_item_id) order by id for update;
 select * into o from offers where id=offer_uuid for update;
 if o.status not in('accepted','completed') then raise exception 'Cannot dispute this offer'; end if;
 insert into reports(reporter_id,offer_id,reason) values(auth.uid(),o.id,details);
 update offers set status='disputed' where id=o.id;
 update items set status='reserved' where id in(o.offered_item_id,o.requested_item_id);
end; $$;
-- New functions default to PUBLIC execute, so explicitly restrict the API.
revoke execute on function public.on_signup() from public,anon,authenticated;
revoke execute on function public.create_offer(uuid,uuid),public.respond_offer(uuid,text),public.my_handover_code(uuid),public.confirm_handover(uuid,text),public.report_swap(uuid,text) from public,anon;
grant execute on function public.create_offer(uuid,uuid),public.respond_offer(uuid,text),public.my_handover_code(uuid),public.confirm_handover(uuid,text),public.report_swap(uuid,text) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('item-images','item-images',true,5242880,array['image/jpeg','image/png','image/webp']);
create policy upload_own_image on storage.objects for insert to authenticated with check(bucket_id='item-images' and (storage.foldername(name))[1]=auth.uid()::text);
create policy view_item_images on storage.objects for select using(bucket_id='item-images');
commit;
