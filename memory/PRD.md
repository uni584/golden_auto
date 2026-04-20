# Golden Auto – PRD

## Problem Statement
Full-stack platform for Swedish auto workshop (Golden Auto) covering: verkstad, service, hjulskifte, däckhotell, biltvätt, rekond. Public customer-facing booking website + internal operational admin panel with full audit-first architecture.

## User Choices
- Scope: Full MVP (but user later narrowed to FRONTEND ONLY / graphic design)
- Auth: JWT (mocked in frontend)
- Notifications: mocked
- PDF receipts: mocked (print view)
- Language/design: Swedish, professional/industrial

## Architecture Implemented (Frontend Graphic Design Showcase)
- Dual-theme React app: dark luxury public site + light functional admin panel
- Fonts: Cabinet Grotesk (display) + IBM Plex Sans (body) + JetBrains Mono
- Icons: @phosphor-icons/react
- Animation: Framer Motion (staggered reveals, page transitions)
- All data MOCKED in /app/frontend/src/mock/data.js

## Pages Built
### Public (dark theme)
- / Home (hero, service bento-grid, process steps, CTA band)
- /tjanster — services catalog grouped by category with pricing
- /boka — 4-step multi-step booking wizard
- /kontakt — contact info + form

### Admin (light theme, /admin/*)
- login (split-screen with image)
- dashboard (KPIs, today's bookings, category chart)
- bokningar, kunder, fordon, arbetsorder (with standard action library),
- tjanster, standardatgarder, kvitton (with receipt preview),
- notiser (email/SMS log), auditlogg (timeline), anvandare (roles)

## What's Implemented (2026-04-20)
- Complete visual/design layer with Swedish UI
- All 17 pages routed and functional
- Mock auth (any credentials login)
- Form validation in booking flow
- Data-testid attributes on all interactive elements

## Backlog (if backend wanted)
- P0: Connect to backend (already scaffolded in /app/backend/server.py with JWT auth + MongoDB + PDF generation)
- P1: Real email/SMS integration (Resend/Twilio)
- P1: Real PDF download (reportlab already wired)
- P2: Tire hotel tracking, season reminders
- P2: Reports dashboard with charts
