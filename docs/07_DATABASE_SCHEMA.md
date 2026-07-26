# Database Schema

## Organisasi

### profiles
- id
- full_name
- role
- active_school_id

### schools
- id
- name
- code

### classes
- id
- school_id
- name
- grade_level

### class_members
- class_id
- profile_id
- member_role

## Konten

### content_versions
- id
- version_code
- status
- published_at

### missions
- id
- content_version_id
- code
- title
- order_number
- sample_ref

### intent_rules
- id
- mission_id
- intent_code
- rule_config jsonb
- ar_sequence_code
- response_code

### ar_sequences
- id
- code
- version
- config jsonb

### assets
- id
- asset_code
- file_path
- checksum
- metadata jsonb

## Sesi dan kelompok

### learning_sessions
- id
- class_id
- teacher_id
- content_version_id
- join_code
- status
- station_duration_seconds

### groups
- id
- session_id
- name
- leader_profile_id
- device_installation_id

### group_members
- id
- group_id
- profile_id nullable
- display_name
- is_leader

## Investigasi

### mission_progress
- id
- group_id
- mission_id
- status
- ar_mode
- started_at
- completed_at

### student_questions
- id
- group_id
- mission_id
- question_text
- matched_intent
- confidence
- ar_sequence_code

### observation_records
- id
- group_id
- mission_id
- sample_ref
- detected_structure
- structure_state
- glow_color
- visual_effects
- outer_layer_material
- outer_layer_condition
- function_analysis
- damage_impact
- version

### investigation_conclusions
- id
- group_id
- sample_a_identity
- sample_a_reasoning
- sample_b_identity
- sample_b_reasoning
- group_hypothesis
- status

## POS

### evaluation_stations
- id
- code
- title
- marker_code
- asset_code

### questions
- id
- station_id
- code
- question_text
- question_type
- correct_answer
- rubric
- max_score

### station_assignments
- id
- session_id
- group_id
- station_id
- rotation_number
- status

### station_attempts
- id
- assignment_id
- started_at
- expires_at
- submitted_at
- status

### answers
- id
- group_id
- question_id
- station_attempt_id
- answer_text
- auto_score
- teacher_score
- final_score
- feedback
- version

## RLS

- Anggota hanya membaca/menulis group sendiri.
- Guru hanya mengakses sesi kelasnya.
- Admin mengelola konten.
- Published content dapat dibaca peserta sesi.
