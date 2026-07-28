# Stage 1: Build Go Matching Engine
FROM golang:1.22-alpine AS go-builder
WORKDIR /app/matching-engine
COPY matching-engine/go.mod ./
COPY matching-engine/main.go ./
# Download modules if there are any (fails silently if no dependencies)
RUN go mod download || true
# Compile the binary
RUN go build -o matching-engine main.go

# Stage 2: Build Node.js Backend
FROM node:20-alpine AS node-builder
RUN apk add --no-cache openssl libc6-compat
WORKDIR /app
# Copy package files and prisma schema
COPY package*.json ./
COPY prisma ./prisma/
# Install all dependencies (including dev for building)
RUN npm ci
# Copy source code and build
COPY src ./src/
COPY tsconfig.json ./
RUN npm run build

# Stage 3: Production Runner
FROM node:20-alpine
RUN apk add --no-cache openssl libc6-compat
WORKDIR /app

# Copy package files and prisma schema for production install
COPY package*.json ./
COPY prisma ./prisma/
RUN npm ci --omit=dev
# Generate Prisma client for the production environment
RUN npx prisma generate

# Copy the built Node.js code
COPY --from=node-builder /app/dist ./dist

# Create the matching-engine directory and copy the compiled Go binary
RUN mkdir -p matching-engine
COPY --from=go-builder /app/matching-engine/matching-engine ./matching-engine/matching-engine
RUN chmod +x ./matching-engine/matching-engine

# Set production environment variables
ENV NODE_ENV=production
ENV PORT=8080

EXPOSE 8080

# Run Prisma database push & start Fastify server
CMD ["sh", "-c", "npx prisma db push --skip-generate && npm start"]
