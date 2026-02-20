# OpenMoko Agent Guidelines

Welcome to the OpenMoko codebase. If you are an AI assistant (Agent / Gemini), please read this document before making structural changes to the project.

## Project Overview
OpenMoko is a voice-first, progressive web app (PWA) wrapper around OpenCode. It allows the user to record voice prompts on their phone, transcribe them, automatically reformulate them into precise agent instructions using an LLM, and seamlessly hand them off to an OpenCode agent session. It also handles CI/CD push notifications.

## Architecture & Services
The project uses a 4-container Docker Compose setup routed through Nginx:
1. **`opencode`**: The core AI agent environment (runs on `:8080` internally).
2. **`openmoko-nginx`**: The ingress router (`:7777` mapped to `:80`). See `config/nginx.conf`.
3. **`openmoko-events`**: A Node.js backend (`:3001` internally). Handles GitHub API routing, Webhooks, Push Notifications, Audio Transcription (Whisper), and LLM Reformulation (Groq/Gemini).
4. **`openmoko-init`**: The Vite-built frontend PWA running on `:3000` internally.

## Key Technical Decisions
- **No Database**: State is stored as flat JSON files in the `events_data` Docker volume (`active_session.json`, `repos.json`, `push_subscriptions.json`, `failures/`).
- **Workspace Management**: Projects are cloned into the shared `/workspace` volume by the `events` service via `events/routes/repos.js`. We use `git clone` or, if existing, `git fetch && git reset --hard origin/main` to ensure clean states.
- **Transcription UX Flow**: In `init/src/lib/speech.js`, we use the Web Speech API with a custom timeout loop: 2.5s of silence triggers a "PAUSED" state, revealing a 1-second "Continue Talking" grace-period button before automatically processing the transcript.
- **Frontend Styling**: Native CSS variables in `init/src/style.css` support robust light and dark modes via `@media (prefers-color-scheme: dark)`.

## Single Source of Truth
The Product Requirements Document (PRD) at `doc/prd/openmoko-prd-v0.3.md` is the absolute source of truth for architectural constraints and feature behavior. **Always consult the PRD before fundamentally altering how features operate.**
