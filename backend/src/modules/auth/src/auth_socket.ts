import { FastifyRequest } from 'fastify';
import { AuthService, UserPayload } from './auth_service';
import { logger } from '../../../shared/logger';

export function authenticateSocket(request: FastifyRequest): UserPayload | null {
  try {
    // Look for token in query parameters
    const query = request.query as any;
    const token = query?.token || query?.accessToken;

    if (token) {
      return AuthService.verifyToken(token);
    }
  } catch (err) {
    logger.warn({ err }, 'Socket authentication token failed verification');
  }

  // Fallback to null (allowing custom protocol identification messages e.g. register_driver to declare identity)
  return null;
}
