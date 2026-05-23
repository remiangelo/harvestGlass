-- 1. Schema

create table questions (
  id text primary key,
  prompt text not null,
  weighting text not null check (weighting in ('need','bring','both')),
  display_order int not null,
  created_at timestamptz default now()
);

create table question_options (
  id text primary key,
  question_id text not null references questions(id) on delete cascade,
  label text not null,
  axis text not null check (axis in
    ('emotional_intelligence','stability','integrity','connection','growth')),
  display_order int not null
);

create table user_question_answers (
  user_id uuid not null references users(id) on delete cascade,
  question_id text not null references questions(id) on delete cascade,
  option_id text not null references question_options(id),
  answered_at timestamptz default now(),
  primary key (user_id, question_id)
);

alter table users
  add column profile_graph_side text default 'bring'
    check (profile_graph_side in ('need','bring'));

-- 2. RLS

alter table user_question_answers enable row level security;

create policy "answers_self_read" on user_question_answers
  for select using (auth.uid() = user_id);
create policy "answers_self_write" on user_question_answers
  for insert with check (auth.uid() = user_id);
create policy "answers_self_update" on user_question_answers
  for update using (auth.uid() = user_id);

-- 3. Seed: 10 questions + 50 options

insert into questions (id, prompt, weighting, display_order) values
  ('q1',  'After a hard day, what would help you feel most cared for?',                   'need',  1),
  ('q2',  'Someone disappoints you. What helps repair the moment most?',                  'need',  2),
  ('q3',  'You are starting to trust someone. What makes that trust grow?',               'both',  3),
  ('q4',  'During conflict, what matters most to you?',                                    'need',  4),
  ('q5',  'When you picture long-term love, what feels most important?',                  'need',  5),
  ('q6',  'Someone you care about is stressed. What feels most natural to you?',          'bring', 6),
  ('q7',  'What makes someone feel emotionally mature to you?',                            'both',  7),
  ('q8',  'What keeps you invested when dating gets real?',                                'need',  8),
  ('q9',  'What makes a relationship feel safe enough to deepen?',                         'need',  9),
  ('q10', 'What would make you feel proud to choose someone?',                             'both',  10);

insert into question_options (id, question_id, label, axis, display_order) values
  ('q1_a','q1','They really listen before responding.',                'emotional_intelligence', 1),
  ('q1_b','q1','They stay calm and steady with me.',                   'stability',              2),
  ('q1_c','q1','They make it feel safe to be fully myself.',           'integrity',              3),
  ('q1_d','q1','They pull me close and make time for me.',             'connection',             4),
  ('q1_e','q1','They help me see a way forward.',                      'growth',                 5),

  ('q2_a','q2','They understand why it hurt.',                         'emotional_intelligence', 1),
  ('q2_b','q2','They show up better next time.',                       'stability',              2),
  ('q2_c','q2','They own their part clearly.',                         'integrity',              3),
  ('q2_d','q2','They make time to reconnect.',                         'connection',             4),
  ('q2_e','q2','They want to learn from it.',                          'growth',                 5),

  ('q3_a','q3','They notice what you feel.',                           'emotional_intelligence', 1),
  ('q3_b','q3','Their energy stays steady.',                           'stability',              2),
  ('q3_c','q3','Their actions match their words.',                     'integrity',              3),
  ('q3_d','q3','You feel close and wanted.',                           'connection',             4),
  ('q3_e','q3','They keep growing through life.',                      'growth',                 5),

  ('q4_a','q4','They try to understand you.',                          'emotional_intelligence', 1),
  ('q4_b','q4','They slow the moment down.',                           'stability',              2),
  ('q4_c','q4','They take ownership.',                                 'integrity',              3),
  ('q4_d','q4','They come back toward you emotionally.',               'connection',             4),
  ('q4_e','q4','They care more about growing than winning.',           'growth',                 5),

  ('q5_a','q5','Feeling emotionally known.',                           'emotional_intelligence', 1),
  ('q5_b','q5','Knowing I can count on how they show up.',             'stability',              2),
  ('q5_c','q5','Feeling secure in their character.',                   'integrity',              3),
  ('q5_d','q5','Feeling wanted and close.',                            'connection',             4),
  ('q5_e','q5','Feeling like you are building something meaningful.',  'growth',                 5),

  ('q6_a','q6','Help them feel understood.',                           'emotional_intelligence', 1),
  ('q6_b','q6','Help steady the situation.',                           'stability',              2),
  ('q6_c','q6','Help them face the situation honestly.',               'integrity',              3),
  ('q6_d','q6','Offer warmth and closeness.',                          'connection',             4),
  ('q6_e','q6','Encourage their next step.',                           'growth',                 5),

  ('q7_a','q7','They can read the room emotionally.',                  'emotional_intelligence', 1),
  ('q7_b','q7','They stay steady under pressure.',                     'stability',              2),
  ('q7_c','q7','They admit when they were wrong.',                     'integrity',              3),
  ('q7_d','q7','They keep reaching toward the people they love.',      'connection',             4),
  ('q7_e','q7','They reflect and adjust.',                             'growth',                 5),

  ('q8_a','q8','They care about your inner world.',                    'emotional_intelligence', 1),
  ('q8_b','q8','Their effort stays steady.',                           'stability',              2),
  ('q8_c','q8','The way they handle people feels trustworthy.',        'integrity',              3),
  ('q8_d','q8','The bond feels alive.',                                'connection',             4),
  ('q8_e','q8','You see shared direction.',                            'growth',                 5),

  ('q9_a','q9','You feel emotionally understood.',                     'emotional_intelligence', 1),
  ('q9_b','q9','Their presence feels steady over time.',               'stability',              2),
  ('q9_c','q9','You trust how they handle hard things.',               'integrity',              3),
  ('q9_d','q9','You feel wanted in their life.',                       'connection',             4),
  ('q9_e','q9','You feel like the relationship has purpose.',          'growth',                 5),

  ('q10_a','q10','Their care for people is genuine.',                  'emotional_intelligence', 1),
  ('q10_b','q10','Their life feels steady and dependable.',            'stability',              2),
  ('q10_c','q10','Their character shows when things are hard.',        'integrity',              3),
  ('q10_d','q10','They make love feel warm and alive.',                'connection',             4),
  ('q10_e','q10','They keep becoming a better version of themselves.', 'growth',                 5);
