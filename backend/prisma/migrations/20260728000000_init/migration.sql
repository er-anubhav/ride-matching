-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "auth";

-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "kyc";

-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "payment";

-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "pricing";

-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "trip";

-- CreateTable
CREATE TABLE "auth"."users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "phone" VARCHAR(15) NOT NULL,
    "name" VARCHAR(100),
    "email" VARCHAR(255),
    "role" VARCHAR(20) NOT NULL DEFAULT 'RIDER',
    "status" VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "auth"."user_devices" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "device_id" VARCHAR(255) NOT NULL,
    "platform" VARCHAR(50),
    "fcm_token" VARCHAR(255) NOT NULL,
    "app_version" VARCHAR(50),
    "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_devices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "auth"."sessions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "refresh_token_hash" VARCHAR(64) NOT NULL,
    "device_id" VARCHAR(255),
    "user_agent" TEXT,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "auth"."otp_codes" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "phone" VARCHAR(15) NOT NULL,
    "code_hash" VARCHAR(64) NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "used_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "otp_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "auth"."saved_places" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "label" VARCHAR(50) NOT NULL,
    "address" TEXT NOT NULL,
    "latitude" DECIMAL(10,7) NOT NULL,
    "longitude" DECIMAL(10,7) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "saved_places_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "auth"."support_tickets" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "subject" VARCHAR(255) NOT NULL,
    "category" VARCHAR(50) NOT NULL DEFAULT 'GENERAL',
    "description" TEXT NOT NULL,
    "status" VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "support_tickets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trip"."trips" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "rider_id" UUID NOT NULL,
    "driver_id" UUID,
    "city_id" VARCHAR(50) NOT NULL,
    "vehicle_type" VARCHAR(20) NOT NULL,
    "status" VARCHAR(30) NOT NULL DEFAULT 'REQUESTED',
    "pickup_lat" DECIMAL(10,7) NOT NULL,
    "pickup_lng" DECIMAL(10,7) NOT NULL,
    "pickup_address" TEXT,
    "dropoff_lat" DECIMAL(10,7) NOT NULL,
    "dropoff_lng" DECIMAL(10,7) NOT NULL,
    "dropoff_address" TEXT,
    "estimated_fare" DECIMAL(10,2),
    "final_fare" DECIMAL(10,2),
    "distance_km" DECIMAL(8,3),
    "duration_minutes" INTEGER,
    "rider_otp" VARCHAR(4),
    "surge_multiplier" DECIMAL(4,2) NOT NULL DEFAULT 1.00,
    "promo_code" VARCHAR(30),
    "promo_discount" DECIMAL(10,2),
    "cancelled_by" UUID,
    "cancellation_reason" VARCHAR(100),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "started_at" TIMESTAMP(3),
    "completed_at" TIMESTAMP(3),

    CONSTRAINT "trips_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trip"."trip_events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "trip_id" UUID NOT NULL,
    "event_type" VARCHAR(50) NOT NULL,
    "actor_id" UUID,
    "payload" JSONB,
    "occurred_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "trip_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trip"."gps_tracks" (
    "trip_id" UUID NOT NULL,
    "lat" DECIMAL(10,7) NOT NULL,
    "lng" DECIMAL(10,7) NOT NULL,
    "heading" SMALLINT,
    "speed_kmh" DECIMAL(6,2),
    "recorded_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "gps_tracks_pkey" PRIMARY KEY ("trip_id","recorded_at")
);

-- CreateTable
CREATE TABLE "trip"."ratings" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "trip_id" UUID NOT NULL,
    "rider_id" UUID NOT NULL,
    "driver_id" UUID NOT NULL,
    "rider_rating" SMALLINT,
    "driver_rating" SMALLINT,
    "rider_comment" TEXT,
    "driver_comment" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ratings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment"."payments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "trip_id" UUID NOT NULL,
    "rider_id" UUID NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "currency" VARCHAR(3) NOT NULL DEFAULT 'INR',
    "method" VARCHAR(30) NOT NULL,
    "status" VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    "gateway" VARCHAR(20),
    "gateway_payment_id" VARCHAR(100),
    "gateway_order_id" VARCHAR(100),
    "failure_reason" TEXT,
    "collected_by" VARCHAR(20),
    "collected_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "settled_at" TIMESTAMP(3),

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment"."wallets" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "balance" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wallets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment"."wallet_transactions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "wallet_id" UUID NOT NULL,
    "type" VARCHAR(20) NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "balance_after" DECIMAL(10,2) NOT NULL,
    "description" TEXT,
    "reference_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wallet_transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment"."payouts" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "driver_id" UUID NOT NULL,
    "gross_amount" DECIMAL(10,2) NOT NULL,
    "commission" DECIMAL(10,2) NOT NULL,
    "net_amount" DECIMAL(10,2) NOT NULL,
    "period_start" DATE NOT NULL,
    "period_end" DATE NOT NULL,
    "status" VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    "utr" VARCHAR(50),
    "upi_id" VARCHAR(100),
    "initiated_at" TIMESTAMP(3),
    "settled_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payouts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pricing"."city_configs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "city_id" VARCHAR(50) NOT NULL,
    "vehicle_type" VARCHAR(20) NOT NULL,
    "base_fare" DECIMAL(8,2) NOT NULL,
    "per_km_rate" DECIMAL(8,2) NOT NULL,
    "per_min_rate" DECIMAL(8,2) NOT NULL,
    "minimum_fare" DECIMAL(8,2) NOT NULL,
    "commission_pct" DECIMAL(5,2) NOT NULL DEFAULT 20.00,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "effective_from" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "city_configs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pricing"."surge_events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "city_id" VARCHAR(50) NOT NULL,
    "h3_cell" VARCHAR(20) NOT NULL,
    "multiplier" DECIMAL(4,2) NOT NULL,
    "demand_ratio" DECIMAL(6,2),
    "started_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ended_at" TIMESTAMP(3),

    CONSTRAINT "surge_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pricing"."promo_codes" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "code" VARCHAR(30) NOT NULL,
    "discount_type" VARCHAR(20) NOT NULL,
    "discount_value" DECIMAL(8,2) NOT NULL,
    "max_discount" DECIMAL(8,2),
    "min_fare" DECIMAL(8,2),
    "max_uses" INTEGER,
    "uses_count" INTEGER NOT NULL DEFAULT 0,
    "user_max_uses" INTEGER NOT NULL DEFAULT 1,
    "valid_from" TIMESTAMP(3) NOT NULL,
    "valid_until" TIMESTAMP(3) NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "promo_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kyc"."driver_profiles" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "driver_id" UUID NOT NULL,
    "vehicle_type" VARCHAR(20) NOT NULL,
    "vehicle_make" VARCHAR(50),
    "vehicle_model" VARCHAR(50),
    "vehicle_year" SMALLINT,
    "vehicle_color" VARCHAR(30),
    "licence_plate" VARCHAR(15) NOT NULL,
    "upi_id" VARCHAR(100),
    "kyc_status" VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    "approved_by" UUID,
    "approval_note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "driver_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kyc"."documents" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "driver_id" UUID NOT NULL,
    "doc_type" VARCHAR(30) NOT NULL,
    "s3_key" VARCHAR(500) NOT NULL,
    "verification_status" VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    "verified_at" TIMESTAMP(3),
    "rejection_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "documents_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_phone_key" ON "auth"."users"("phone");

-- CreateIndex
CREATE INDEX "user_devices_user_id_is_active_idx" ON "auth"."user_devices"("user_id", "is_active");

-- CreateIndex
CREATE UNIQUE INDEX "user_devices_user_id_device_id_key" ON "auth"."user_devices"("user_id", "device_id");

-- CreateIndex
CREATE UNIQUE INDEX "sessions_refresh_token_hash_key" ON "auth"."sessions"("refresh_token_hash");

-- CreateIndex
CREATE INDEX "sessions_user_id_expires_at_idx" ON "auth"."sessions"("user_id", "expires_at");

-- CreateIndex
CREATE INDEX "otp_codes_phone_expires_at_idx" ON "auth"."otp_codes"("phone", "expires_at");

-- CreateIndex
CREATE INDEX "saved_places_user_id_idx" ON "auth"."saved_places"("user_id");

-- CreateIndex
CREATE INDEX "support_tickets_user_id_status_idx" ON "auth"."support_tickets"("user_id", "status");

-- CreateIndex
CREATE INDEX "trips_rider_id_created_at_idx" ON "trip"."trips"("rider_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "trips_driver_id_status_idx" ON "trip"."trips"("driver_id", "status");

-- CreateIndex
CREATE INDEX "trips_status_created_at_idx" ON "trip"."trips"("status", "created_at" DESC);

-- CreateIndex
CREATE INDEX "trip_events_trip_id_occurred_at_idx" ON "trip"."trip_events"("trip_id", "occurred_at");

-- CreateIndex
CREATE INDEX "gps_tracks_trip_id_recorded_at_idx" ON "trip"."gps_tracks"("trip_id", "recorded_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "ratings_trip_id_key" ON "trip"."ratings"("trip_id");

-- CreateIndex
CREATE UNIQUE INDEX "payments_trip_id_key" ON "payment"."payments"("trip_id");

-- CreateIndex
CREATE INDEX "payments_rider_id_created_at_idx" ON "payment"."payments"("rider_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "payments_status_created_at_idx" ON "payment"."payments"("status", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "wallets_user_id_key" ON "payment"."wallets"("user_id");

-- CreateIndex
CREATE INDEX "wallet_transactions_wallet_id_created_at_idx" ON "payment"."wallet_transactions"("wallet_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "payouts_driver_id_period_start_idx" ON "payment"."payouts"("driver_id", "period_start" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "city_configs_city_id_vehicle_type_effective_from_key" ON "pricing"."city_configs"("city_id", "vehicle_type", "effective_from");

-- CreateIndex
CREATE INDEX "surge_events_city_id_h3_cell_started_at_idx" ON "pricing"."surge_events"("city_id", "h3_cell", "started_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "promo_codes_code_key" ON "pricing"."promo_codes"("code");

-- CreateIndex
CREATE UNIQUE INDEX "driver_profiles_driver_id_key" ON "kyc"."driver_profiles"("driver_id");

-- CreateIndex
CREATE INDEX "documents_driver_id_doc_type_idx" ON "kyc"."documents"("driver_id", "doc_type");

-- AddForeignKey
ALTER TABLE "auth"."user_devices" ADD CONSTRAINT "user_devices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "auth"."sessions" ADD CONSTRAINT "sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "auth"."saved_places" ADD CONSTRAINT "saved_places_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "auth"."support_tickets" ADD CONSTRAINT "support_tickets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trip"."trips" ADD CONSTRAINT "trips_rider_id_fkey" FOREIGN KEY ("rider_id") REFERENCES "auth"."users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trip"."trips" ADD CONSTRAINT "trips_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "auth"."users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trip"."trip_events" ADD CONSTRAINT "trip_events_trip_id_fkey" FOREIGN KEY ("trip_id") REFERENCES "trip"."trips"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trip"."trip_events" ADD CONSTRAINT "trip_events_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trip"."gps_tracks" ADD CONSTRAINT "gps_tracks_trip_id_fkey" FOREIGN KEY ("trip_id") REFERENCES "trip"."trips"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trip"."ratings" ADD CONSTRAINT "ratings_trip_id_fkey" FOREIGN KEY ("trip_id") REFERENCES "trip"."trips"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trip"."ratings" ADD CONSTRAINT "ratings_rider_id_fkey" FOREIGN KEY ("rider_id") REFERENCES "auth"."users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trip"."ratings" ADD CONSTRAINT "ratings_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "auth"."users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payment"."payments" ADD CONSTRAINT "payments_trip_id_fkey" FOREIGN KEY ("trip_id") REFERENCES "trip"."trips"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payment"."payments" ADD CONSTRAINT "payments_rider_id_fkey" FOREIGN KEY ("rider_id") REFERENCES "auth"."users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payment"."wallets" ADD CONSTRAINT "wallets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payment"."wallet_transactions" ADD CONSTRAINT "wallet_transactions_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "payment"."wallets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payment"."payouts" ADD CONSTRAINT "payouts_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "auth"."users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kyc"."driver_profiles" ADD CONSTRAINT "driver_profiles_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "auth"."users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kyc"."documents" ADD CONSTRAINT "documents_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

