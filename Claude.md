# CLAUDE.md
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 1. Build System
- **Docker Compose**: Use `docker-compose up --build` to build and start the project.
- **Development Build**: Run `docker-compose build` to rebuild Docker containers.
- **Database Setup**: Migrate Prisma models with `npm run prisma:dev` during development.

## 2. Code Structure
- **Main Components**:
  - `backend/`: Contains Docker configuration, ESLint rules, and Prisma schema.
  - `matching-engine/`: Core application logic (entry point).
  - `node_modules/`: Auto-installed dependencies.

## 3. Common Development Tasks
- **Run Application**: `docker-compose up -d`
- **Run Tests**: `npm test`
- **Lint Code**: `npm run lint`
- **Fix Lint Errors**: Use `npm run lint:fix`
- **Pre-commit Checks**: `npm run prepare-commit-msg`

## 4. Built-in Configuration
- **.env.production**: Environment variables for production (never commit changes here).
- **Dockerfile**: Multi-stage build configuration.
- **.eslintrc.js**: JavaScript/TypeScript linting rules.

## 5. Audit Reports
- **Product Integration Matrix**: `docs/product_integration_matrix.md`
- **Backend Audit Report**: `docs/backend_audit_report.md`
- **Execution Roadmap**: `docs/execution_roadmap.md`

## 6. Design Documentation
- **PDP**: `docs/PDP.md`
- **Knowledge Base**: `docs/knowledge_base.md`
- **Database Relations**: `docs/database_relations.md`