# Mr. Rideo Engineering Knowledge Base

Welcome to the single source of truth for the Mr. Rideo backend architecture, infrastructure, and engineering decisions.

## Table of Contents

- [System Overview](#system-overview)
- [Architecture Decision Records (ADRs)](#architecture-decision-records)
- [Database Schema](#database-schema)
- [API Documentation](#api-documentation)
- [Matching Engine](#matching-engine)
- [Trip Lifecycle](#trip-lifecycle)
- [Pricing Engine](#pricing-engine)
- [Authentication](#authentication)
- [Notifications & WebSockets](#notifications--websockets)
- [Infrastructure & Deployment](#infrastructure--deployment)

---

## System Overview
Mr. Rideo is a ride-hailing platform built using a Modular Monolith architecture.
- **Runtime:** Node.js (TypeScript) + Fastify
- **Database:** PostgreSQL (Prisma ORM)
- **Caching & State:** Redis
- **Background Jobs:** BullMQ
- **Real-time:** WebSockets + Redis Pub/Sub
- **Core Matching Engine:** Go (Compiled Binary invoked via IPC)

*(Documentation will be appended here continuously upon completion of features as per the 9-Phase process.)*

## Architecture Documentation
- [Database Relational Integrity](file:///home/anubhavtripathi/Documents/Projects/Freelance Project/mr-rideo/docs/database_relations.md)

## API Documentation
- [Driver Trip Interaction API](file:///home/anubhavtripathi/Documents/Projects/Freelance Project/mr-rideo/docs/driver_trip_api.md)
