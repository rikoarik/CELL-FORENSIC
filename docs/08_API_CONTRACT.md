# API Contract

Base:
`/functions/v1`

## Join session

```http
POST /join-session
```

```json
{
  "join_code": "CF-82KD",
  "display_name": "Riko",
  "installation_id": "uuid"
}
```

## Create group

```http
POST /groups
```

```json
{
  "session_id": "uuid",
  "name": "Kelompok 1",
  "members": [
    {"display_name": "Riko"},
    {"display_name": "Ayu"}
  ]
}
```

## Content pack

```http
GET /content-pack?session_id=uuid
```

Mengembalikan:
- missions
- intent_rules
- responses
- ar_sequences
- stations
- questions
- asset manifest

## Ask assistant

```http
POST /assistant/ask
```

```json
{
  "session_id": "uuid",
  "group_id": "uuid",
  "mission_code": "mission_1",
  "question_text": "Periksa organel Sampel A",
  "input_mode": "text"
}
```

Response:
```json
{
  "intent": "inspect_sample_a_organel",
  "confidence": 0.97,
  "response_text": "Hasil pemindaian menunjukkan...",
  "analysis_prompt": "Apa dampaknya...",
  "ar_sequence_code": "zoom_chloroplast_vacuole"
}
```

## Observation

```http
PUT /observations/{id}
```

## Complete mission

```http
POST /missions/complete
```

## Submit investigation

```http
POST /investigation/submit
```

## Start station

```http
POST /stations/start
```

## Save answer

```http
PUT /stations/attempts/{attemptId}/answers/{questionId}
```

## Submit station

```http
POST /stations/attempts/{attemptId}/submit
```

## Teacher overview

```http
GET /teacher/sessions/{sessionId}/overview
```

## Review answer

```http
POST /teacher/answers/{answerId}/review
```
