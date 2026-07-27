import { FastifyReply, FastifyRequest } from 'fastify';
import { AuthService } from './auth_service';
import { UnauthorizedError } from '../../../shared/errors';

export async function verifyJwtMiddleware(request: FastifyRequest, reply: FastifyReply) {
  try {
    const authHeader = request.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedError('Missing or malformed Authorization header');
    }

    const token = authHeader.substring(7);
    const decoded = AuthService.verifyToken(token);
    (request as any).user = decoded;
  } catch (err: any) {
    if (err instanceof UnauthorizedError) {
      return reply.code(err.statusCode).send(err.toRFC7807(request.url));
    }
    return reply.code(401).send({ error: 'Unauthorized' });
  }
}
