"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyJwtMiddleware = verifyJwtMiddleware;
const auth_service_1 = require("./auth_service");
const errors_1 = require("../../../shared/errors");
async function verifyJwtMiddleware(request, reply) {
    try {
        const authHeader = request.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            throw new errors_1.UnauthorizedError('Missing or malformed Authorization header');
        }
        const token = authHeader.substring(7);
        const decoded = auth_service_1.AuthService.verifyToken(token);
        request.user = decoded;
    }
    catch (err) {
        if (err instanceof errors_1.UnauthorizedError) {
            return reply.code(err.statusCode).send(err.toRFC7807(request.url));
        }
        return reply.code(401).send({ error: 'Unauthorized' });
    }
}
