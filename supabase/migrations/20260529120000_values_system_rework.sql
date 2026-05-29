-- =============================================================
-- Values System Rework
-- See docs/superpowers/specs/2026-05-27-values-system-rework-design.md
--
-- 1. Reseed `values` to flat 20-value list (no more 6-category grouping)
-- 2. Reseed `questions` + `question_options` (10 onboarding + 25 deep-dive = 35 Qs)
-- 3. Clear user picks (`user_values_brought`/`sought`) and answers
--    (`user_question_answers`) so existing users retake the questionnaire
-- =============================================================

-- 1. Clear user-side data first to satisfy FK constraints
delete from user_values_brought;
delete from user_values_sought;
delete from user_question_answers;

-- 2. Reseed `values` to flat 20-value list (values.id is uuid)
delete from values;

insert into values (id, name, category) values
  (gen_random_uuid(), 'Empathetic',           'general'),
  (gen_random_uuid(), 'Compassionate',        'general'),
  (gen_random_uuid(), 'Active Listener',      'general'),
  (gen_random_uuid(), 'Supportive',           'general'),
  (gen_random_uuid(), 'Reliable',             'general'),
  (gen_random_uuid(), 'Consistent',           'general'),
  (gen_random_uuid(), 'Grounded',             'general'),
  (gen_random_uuid(), 'Responsible',          'general'),
  (gen_random_uuid(), 'Honest & Transparent', 'general'),
  (gen_random_uuid(), 'Accountable',          'general'),
  (gen_random_uuid(), 'Respectful',           'general'),
  (gen_random_uuid(), 'Loyal',                'general'),
  (gen_random_uuid(), 'Affectionate',         'general'),
  (gen_random_uuid(), 'Passionate',           'general'),
  (gen_random_uuid(), 'Quality Time',         'general'),
  (gen_random_uuid(), 'Playful',              'general'),
  (gen_random_uuid(), 'Ambitious',            'general'),
  (gen_random_uuid(), 'Optimistic',           'general'),
  (gen_random_uuid(), 'Independent',          'general'),
  (gen_random_uuid(), 'Intentional',          'general');

-- 3. Reseed questions: rewrite Q1-Q10 (onboarding), add Q11-Q35 (deep-dive)
delete from question_options;
delete from questions;

insert into questions (id, prompt, weighting, display_order) values
  -- Onboarding (Q1-Q10): 5 NEED, 5 BRING
  ('q1',  'After a hard day, what would help you feel most cared for?',                                       'need',   1),
  ('q2',  'Someone disappoints you. What helps repair the moment most?',                                      'need',   2),
  ('q3',  'Someone you care about is stressed. What feels most natural for you to offer?',                    'bring',  3),
  ('q4',  'When conflict happens, what do you naturally try to bring into the moment?',                       'bring',  4),
  ('q5',  'You are starting to trust someone. What makes that trust grow most for you?',                      'need',   5),
  ('q6',  'When you picture what you bring to long-term love, what feels most true?',                         'bring',  6),
  ('q7',  'You are nervous before something important. What kind of support would help most?',                'need',   7),
  ('q8',  'When you realize you may have hurt or disappointed someone, what do you most want to do?',         'bring',  8),
  ('q9',  'What makes you feel respected in a relationship?',                                                 'need',   9),
  ('q10', 'During a quiet evening together, what do you most naturally hope to bring?',                       'bring', 10),
  -- Deep-dive (Q11-Q35): 12 NEED, 12 BRING, 1 BOTH
  ('q11', 'Someone shares something vulnerable with you. What do you naturally try to offer?',                'bring', 11),
  ('q12', 'Plans change at the last minute. What matters most to you?',                                       'need',  12),
  ('q13', 'You feel misunderstood. What helps most?',                                                          'need',  13),
  ('q14', 'When you make a mistake, what do you naturally try to do afterward?',                              'bring', 14),
  ('q15', 'When you imagine building a life with someone, what do you most need to feel secure?',             'need',  15),
  ('q16', 'Someone you love is nervous before something important. What feels most natural for you to offer?','bring', 16),
  ('q17', 'What makes you feel respected?',                                                                    'need',  17),
  ('q18', 'When life gets stressful, what do you hope someone can count on you for?',                         'bring', 18),
  ('q19', 'You are excited about a personal goal. What response would mean the most?',                        'need',  19),
  ('q20', 'When attraction starts feeling more serious, what do you most want to bring into the connection?', 'bring', 20),
  ('q21', 'A conversation gets tense. What do you need most from the other person?',                          'need',  21),
  ('q22', 'What do you most naturally do to help someone feel chosen?',                                       'bring', 22),
  ('q23', 'You share a concern. What response builds the most confidence?',                                   'need',  23),
  ('q24', 'What do you most want to be dependable for in a relationship?',                                    'bring', 24),
  ('q25', 'You are spending a quiet evening together. What feels most meaningful to you?',                    'need',  25),
  ('q26', 'When you are under pressure, what do you hope your character shows?',                              'bring', 26),
  ('q27', 'What kind of apology means the most to you?',                                                       'need',  27),
  ('q28', 'What do you most want to offer so someone feels free to be themselves?',                           'bring', 28),
  ('q29', 'What makes love feel alive to you?',                                                                'need',  29),
  ('q30', 'When you disagree about something important, what do you naturally try to bring?',                 'bring', 30),
  ('q31', 'What makes someone feel like a safe long-term choice?',                                            'need',  31),
  ('q32', 'Shared spiritual or philosophical values feel meaningful when they shape what?',                   'both',  32),
  ('q33', 'What makes you feel supportive in a relationship?',                                                'bring', 33),
  ('q34', 'What do you hope someone notices about what you bring?',                                           'bring', 34),
  ('q35', 'When you imagine healthy love, what feels most like home?',                                        'need',  35);

insert into question_options (id, question_id, label, axis, display_order) values
  -- Q1 (NEED, omits Growth)
  ('q1_a','q1','They really listen before responding.',                                'emotional_intelligence', 1),
  ('q1_b','q1','They stay calm and steady with me.',                                   'stability',              2),
  ('q1_c','q1','They are honest, respectful, and present with what I am feeling.',    'integrity',              3),
  ('q1_d','q1','They pull me close and make time for me.',                             'connection',             4),

  -- Q2 (NEED, omits Connection)
  ('q2_a','q2','They understand why it hurt.',                                         'emotional_intelligence', 1),
  ('q2_b','q2','They show up more consistently afterward.',                            'stability',              2),
  ('q2_c','q2','They own their part clearly.',                                         'integrity',              3),
  ('q2_d','q2','They reflect on what happened and try to grow from it.',               'growth',                 4),

  -- Q3 (BRING, omits Integrity)
  ('q3_a','q3','I help them feel understood.',                                         'emotional_intelligence', 1),
  ('q3_b','q3','I help steady the situation.',                                         'stability',              2),
  ('q3_c','q3','I offer warmth, affection, or closeness.',                             'connection',             3),
  ('q3_d','q3','I encourage their next step forward.',                                 'growth',                 4),

  -- Q4 (BRING, omits Stability)
  ('q4_a','q4','I try to understand what the other person is really feeling.',        'emotional_intelligence', 1),
  ('q4_b','q4','I try to own my part honestly.',                                       'integrity',              2),
  ('q4_c','q4','I try to protect the bond and come back toward closeness.',            'connection',             3),
  ('q4_d','q4','I try to learn from it and find a better way forward.',                'growth',                 4),

  -- Q5 (NEED, omits Emotional Intelligence)
  ('q5_a','q5','Their energy stays steady over time.',                                 'stability',              1),
  ('q5_b','q5','Their actions match their words.',                                     'integrity',              2),
  ('q5_c','q5','You feel wanted and close.',                                           'connection',             3),
  ('q5_d','q5','You can see shared direction and growth.',                             'growth',                 4),

  -- Q6 (BRING, omits Growth)
  ('q6_a','q6','I bring emotional care and understanding.',                            'emotional_intelligence', 1),
  ('q6_b','q6','I bring steadiness and dependability.',                                'stability',              2),
  ('q6_c','q6','I bring honesty, loyalty, and respect.',                               'integrity',              3),
  ('q6_d','q6','I bring warmth, affection, and connection.',                           'connection',             4),

  -- Q7 (NEED, omits Connection)
  ('q7_a','q7','They notice how I am feeling and comfort me.',                         'emotional_intelligence', 1),
  ('q7_b','q7','They help me feel grounded and steady.',                               'stability',              2),
  ('q7_c','q7','They help me face the situation honestly.',                            'integrity',              3),
  ('q7_d','q7','They remind me what I am capable of.',                                 'growth',                 4),

  -- Q8 (BRING, omits Integrity)
  ('q8_a','q8','I want to understand how it affected them.',                           'emotional_intelligence', 1),
  ('q8_b','q8','I want to show up better and be more consistent.',                     'stability',              2),
  ('q8_c','q8','I want to reconnect and help them feel cared for.',                    'connection',             3),
  ('q8_d','q8','I want to reflect, adjust, and grow from it.',                         'growth',                 4),

  -- Q9 (NEED, omits Stability)
  ('q9_a','q9','They consider my feelings.',                                           'emotional_intelligence', 1),
  ('q9_b','q9','They honor my boundaries.',                                            'integrity',              2),
  ('q9_c','q9','They make space for me in their life.',                                'connection',             3),
  ('q9_d','q9','They take my goals seriously.',                                        'growth',                 4),

  -- Q10 (BRING, omits Emotional Intelligence)
  ('q10_a','q10','A peaceful, steady presence.',                                       'stability',              1),
  ('q10_b','q10','A space where honesty feels safe.',                                  'integrity',              2),
  ('q10_c','q10','Warmth, closeness, or playfulness.',                                 'connection',             3),
  ('q10_d','q10','Meaningful conversation about dreams, purpose, or direction.',       'growth',                 4),

  -- Q11 (BRING, omits Growth)
  ('q11_a','q11','I try to understand what they are feeling.',                         'emotional_intelligence', 1),
  ('q11_b','q11','I stay steady and present with them.',                               'stability',              2),
  ('q11_c','q11','I treat their honesty with respect.',                                'integrity',              3),
  ('q11_d','q11','I move closer emotionally so they do not feel alone.',               'connection',             4),

  -- Q12 (NEED, omits Connection)
  ('q12_a','q12','They care how the change affects me.',                               'emotional_intelligence', 1),
  ('q12_b','q12','They communicate early and follow through later.',                   'stability',              2),
  ('q12_c','q12','They handle the change with respect.',                               'integrity',              3),
  ('q12_d','q12','They try to handle it better next time.',                            'growth',                 4),

  -- Q13 (NEED, omits Growth)
  ('q13_a','q13','They ask questions before assuming.',                                'emotional_intelligence', 1),
  ('q13_b','q13','They keep the conversation calm.',                                   'stability',              2),
  ('q13_c','q13','They speak plainly and fairly.',                                     'integrity',              3),
  ('q13_d','q13','They reassure me through closeness.',                                'connection',             4),

  -- Q14 (BRING, omits Connection)
  ('q14_a','q14','I try to understand the impact.',                                    'emotional_intelligence', 1),
  ('q14_b','q14','I try to show steadier behavior over time.',                         'stability',              2),
  ('q14_c','q14','I own my part clearly.',                                             'integrity',              3),
  ('q14_d','q14','I reflect on what I can learn from it.',                             'growth',                 4),

  -- Q15 (NEED, omits Emotional Intelligence)
  ('q15_a','q15','They are dependable in daily life.',                                 'stability',              1),
  ('q15_b','q15','They live by strong character.',                                     'integrity',              2),
  ('q15_c','q15','They keep closeness active.',                                        'connection',             3),
  ('q15_d','q15','They move toward purpose with me.',                                  'growth',                 4),

  -- Q16 (BRING, omits Stability)
  ('q16_a','q16','I notice what they are feeling and try to comfort them.',            'emotional_intelligence', 1),
  ('q16_b','q16','I help them face the moment honestly.',                              'integrity',              2),
  ('q16_c','q16','I stay close and present.',                                          'connection',             3),
  ('q16_d','q16','I remind them what they are capable of.',                            'growth',                 4),

  -- Q17 (NEED, omits Connection)
  ('q17_a','q17','They consider my feelings.',                                         'emotional_intelligence', 1),
  ('q17_b','q17','They treat my time with care.',                                      'stability',              2),
  ('q17_c','q17','They honor my boundaries.',                                          'integrity',              3),
  ('q17_d','q17','They take my goals seriously.',                                      'growth',                 4),

  -- Q18 (BRING, omits Growth)
  ('q18_a','q18','I try to be emotionally aware and caring.',                          'emotional_intelligence', 1),
  ('q18_b','q18','I try to stay steady under pressure.',                               'stability',              2),
  ('q18_c','q18','I try to act with character even when it is hard.',                  'integrity',              3),
  ('q18_d','q18','I try to keep warmth alive between us.',                             'connection',             4),

  -- Q19 (NEED, omits Integrity)
  ('q19_a','q19','They understand why it matters to me.',                              'emotional_intelligence', 1),
  ('q19_b','q19','They help me stay grounded.',                                        'stability',              2),
  ('q19_c','q19','They celebrate with me.',                                            'connection',             3),
  ('q19_d','q19','They encourage me toward my potential.',                             'growth',                 4),

  -- Q20 (BRING, omits Stability)
  ('q20_a','q20','I want to be emotionally present and aware.',                        'emotional_intelligence', 1),
  ('q20_b','q20','I want my actions to reflect my character.',                         'integrity',              2),
  ('q20_c','q20','I want the spark to feel mutual and alive.',                         'connection',             3),
  ('q20_d','q20','I want to build toward something meaningful.',                       'growth',                 4),

  -- Q21 (NEED, omits Growth)
  ('q21_a','q21','They listen beneath the words.',                                     'emotional_intelligence', 1),
  ('q21_b','q21','They keep the tone steady.',                                         'stability',              2),
  ('q21_c','q21','They stay fair and truthful.',                                       'integrity',              3),
  ('q21_d','q21','They reach for closeness after.',                                    'connection',             4),

  -- Q22 (BRING, omits Integrity)
  ('q22_a','q22','I remember what matters to them.',                                   'emotional_intelligence', 1),
  ('q22_b','q22','I try to show up consistently over time.',                           'stability',              2),
  ('q22_c','q22','I make real time for them.',                                         'connection',             3),
  ('q22_d','q22','I build toward the future with them.',                               'growth',                 4),

  -- Q23 (NEED, omits Stability)
  ('q23_a','q23','They receive it with care.',                                         'emotional_intelligence', 1),
  ('q23_b','q23','They answer honestly.',                                              'integrity',              2),
  ('q23_c','q23','They soften toward me.',                                             'connection',             3),
  ('q23_d','q23','They look for a better way forward.',                                'growth',                 4),

  -- Q24 (BRING, omits Emotional Intelligence)
  ('q24_a','q24','Doing what I said I would do.',                                      'stability',              1),
  ('q24_b','q24','Handling responsibility with character.',                            'integrity',              2),
  ('q24_c','q24','Continuing to invest in closeness.',                                 'connection',             3),
  ('q24_d','q24','Learning how to show up better over time.',                          'growth',                 4),

  -- Q25 (NEED, omits Growth)
  ('q25_a','q25','The conversation feels emotionally real.',                           'emotional_intelligence', 1),
  ('q25_b','q25','The peace feels easy and steady.',                                   'stability',              2),
  ('q25_c','q25','I feel safe being truthful.',                                        'integrity',              3),
  ('q25_d','q25','The closeness feels warm and natural.',                              'connection',             4),

  -- Q26 (BRING, omits Connection)
  ('q26_a','q26','I still care about people''s feelings.',                             'emotional_intelligence', 1),
  ('q26_b','q26','I can remain steady.',                                               'stability',              2),
  ('q26_c','q26','My values hold even when it is hard.',                               'integrity',              3),
  ('q26_d','q26','I can respond, reflect, and grow.',                                  'growth',                 4),

  -- Q27 (NEED, omits Stability)
  ('q27_a','q27','One that shows they understand my heart.',                           'emotional_intelligence', 1),
  ('q27_b','q27','One that takes full ownership.',                                     'integrity',              2),
  ('q27_c','q27','One that brings us close again.',                                    'connection',             3),
  ('q27_d','q27','One that leads to new growth.',                                      'growth',                 4),

  -- Q28 (BRING, omits Stability)
  ('q28_a','q28','I try to understand their emotions.',                                'emotional_intelligence', 1),
  ('q28_b','q28','I treat their truth with respect.',                                  'integrity',              2),
  ('q28_c','q28','I enjoy their personality.',                                         'connection',             3),
  ('q28_d','q28','I give them room to become more fully themselves.',                  'growth',                 4),

  -- Q29 (NEED, omits Emotional Intelligence)
  ('q29_a','q29','Feeling safe in the rhythm.',                                        'stability',              1),
  ('q29_b','q29','Feeling secure in trust.',                                           'integrity',              2),
  ('q29_c','q29','Feeling wanted, playful, and close.',                                'connection',             3),
  ('q29_d','q29','Feeling inspired together.',                                         'growth',                 4),

  -- Q30 (BRING, omits Stability)
  ('q30_a','q30','I try to care about their perspective.',                             'emotional_intelligence', 1),
  ('q30_b','q30','I try to handle the disagreement with respect.',                     'integrity',              2),
  ('q30_c','q30','I try to protect the bond while talking.',                           'connection',             3),
  ('q30_d','q30','I try to search for a wiser path forward.',                          'growth',                 4),

  -- Q31 (NEED, omits Growth)
  ('q31_a','q31','Their emotional care feels real.',                                   'emotional_intelligence', 1),
  ('q31_b','q31','Their patterns are dependable.',                                     'stability',              2),
  ('q31_c','q31','Their character is clear.',                                          'integrity',              3),
  ('q31_d','q31','Their love feels warm and active.',                                  'connection',             4),

  -- Q32 (BOTH, omits Emotional Intelligence)
  ('q32_a','q32','The way we make life decisions.',                                    'stability',              1),
  ('q32_b','q32','The way we treat people.',                                           'integrity',              2),
  ('q32_c','q32','The depth of closeness between us.',                                 'connection',             3),
  ('q32_d','q32','The meaning we build together.',                                     'growth',                 4),

  -- Q33 (BRING, omits Stability)
  ('q33_a','q33','I can sense what someone may need emotionally.',                     'emotional_intelligence', 1),
  ('q33_b','q33','I protect their dignity.',                                           'integrity',              2),
  ('q33_c','q33','I make them feel loved in real time.',                               'connection',             3),
  ('q33_d','q33','I believe in where they are going.',                                 'growth',                 4),

  -- Q34 (BRING, omits Connection)
  ('q34_a','q34','How deeply I care.',                                                 'emotional_intelligence', 1),
  ('q34_b','q34','How steady I try to be.',                                            'stability',              2),
  ('q34_c','q34','How seriously I take trust.',                                        'integrity',              3),
  ('q34_d','q34','How much I am growing.',                                             'growth',                 4),

  -- Q35 (NEED, omits Integrity)
  ('q35_a','q35','Being understood with care.',                                        'emotional_intelligence', 1),
  ('q35_b','q35','Feeling steady and safe.',                                           'stability',              2),
  ('q35_c','q35','Feeling close, wanted, and joyful.',                                 'connection',             3),
  ('q35_d','q35','Growing into something meaningful together.',                        'growth',                 4);
