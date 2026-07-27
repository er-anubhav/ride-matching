import { FastifyRequest } from 'fastify';
import { UserPayload } from './auth_service';
export declare function authenticateSocket(request: FastifyRequest): UserPayload | null;
