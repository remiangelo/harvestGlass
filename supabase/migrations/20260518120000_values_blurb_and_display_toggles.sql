alter table users
  add column values_blurb text,
  add column show_values_brought boolean default true,
  add column show_values_sought boolean default true,
  add column show_values_blurb boolean default true,
  add column show_values_graph boolean default true;
