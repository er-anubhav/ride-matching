import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const configSchema = z.object({
  PORT: z.preprocess((val) => Number(val ?? 8080), z.number().default(8080)),
  HOST: z.string().default('0.0.0.0'),
  DATABASE_URL: z.string().optional(),
  JWT_SECRET: z.string().default('urban-pulse-super-secret-key-12345'),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  FAST2SMS_API_KEY: z.string().optional(),
  CLOUDFLARE_R2_ACCOUNT_ID: z.string().optional(),
  CLOUDFLARE_R2_ACCESS_KEY_ID: z.string().optional(),
  CLOUDFLARE_R2_SECRET_ACCESS_KEY: z.string().optional(),
  CLOUDFLARE_R2_BUCKET_NAME: z.string().optional(),
  OLA_MAPS_API_KEY: z.string().optional(),

  ENABLE_RATE_LIMIT: z.preprocess((val) => val !== 'false', z.boolean().default(true)),

  DEFAULT_CITY_ID: z.string().optional().default('LKO'),
  ENABLE_DEFAULT_CITY: z.preprocess((val) => val === 'true', z.boolean().default(false)),
  FIREBASE_PROJECT_ID: z.string().optional(),
  FIREBASE_CLIENT_EMAIL: z.string().optional(),
  FIREBASE_PRIVATE_KEY: z.string().optional(),
  ADMIN_USERNAME: z.string().default('admin'),
  ADMIN_PASSWORD: z.string().default('admin123'),
});

export const config = configSchema.parse(process.env);
export type Config = z.infer<typeof configSchema>;
