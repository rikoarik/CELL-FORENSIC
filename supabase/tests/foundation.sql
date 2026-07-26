begin;

select plan(8);
select has_table('public', 'learning_sessions', 'learning_sessions exists');
select has_table('public', 'groups', 'groups exists');
select has_table('public', 'answers', 'answers exists');
select col_has_check('public', 'mission_progress', 'version', 'mission progress version is constrained');
select col_has_check('public', 'answers', 'version', 'answer version is constrained');
select policies_are('public', 'learning_sessions', array['session teacher access'], 'teacher session policy exists');
select policies_are('public', 'observation_records', array['observations group access'], 'group observation policy exists');
select policies_are('public', 'answers', array['answers group or teacher read','answers group update','answers group write','answers teacher review'], 'answer policies exist');

select * from finish();
rollback;
