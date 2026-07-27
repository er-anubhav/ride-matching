"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.config = void 0;
const dotenv_1 = __importDefault(require("dotenv"));
const zod_1 = require("zod");
dotenv_1.default.config();
const configSchema = zod_1.z.object({
    PORT: zod_1.z.preprocess((val) => Number(val ?? 8080), zod_1.z.number().default(8080)),
    HOST: zod_1.z.string().default('0.0.0.0'),
    DATABASE_URL: zod_1.z.string().optional(),
    JWT_SECRET: zod_1.z.string().default('mr-rideo-super-secret-key-12345'),
    NODE_ENV: zod_1.z.enum(['development', 'production', 'test']).default('development'),
    FAST2SMS_API_KEY: zod_1.z.string().optional(),
    CLOUDFLARE_R2_ACCOUNT_ID: zod_1.z.string().optional(),
    CLOUDFLARE_R2_ACCESS_KEY_ID: zod_1.z.string().optional(),
    CLOUDFLARE_R2_SECRET_ACCESS_KEY: zod_1.z.string().optional(),
    CLOUDFLARE_R2_BUCKET_NAME: zod_1.z.string().optional(),
    OLA_MAPS_API_KEY: zod_1.z.string().optional(),
    USE_MOCK_OTP: zod_1.z.preprocess((val) => val === 'true', zod_1.z.boolean().default(false)),
    ENABLE_RATE_LIMIT: zod_1.z.preprocess((val) => val !== 'false', zod_1.z.boolean().default(true)),
    DEFAULT_CITY_ID: zod_1.z.string().optional().default('LKO'),
    ENABLE_DEFAULT_CITY: zod_1.z.preprocess((val) => val === 'true', zod_1.z.boolean().default(false)),
    FIREBASE_PROJECT_ID: zod_1.z.string().optional(),
    FIREBASE_CLIENT_EMAIL: zod_1.z.string().optional(),
    FIREBASE_PRIVATE_KEY: zod_1.z.string().optional(),
    ADMIN_USERNAME: zod_1.z.string().default('admin'),
    ADMIN_PASSWORD: zod_1.z.string().default('admin123'),
});
exports.config = configSchema.parse(process.env);
