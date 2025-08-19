
  create policy "Give users authenticated access to folder 1ffg0oo_0"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using (((bucket_id = 'images'::text) AND ((storage.foldername(name))[1] = 'private'::text) AND (auth.role() = 'authenticated'::text)));



