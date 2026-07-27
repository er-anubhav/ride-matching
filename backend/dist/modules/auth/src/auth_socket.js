"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.authenticateSocket = authenticateSocket;
const auth_service_1 = require("./auth_service");
const logger_1 = require("../../../shared/logger");
function authenticateSocket(request) {
    try {
        // Look for token in query parameters
        const query = request.query;
        const token = query?.token || query?.accessToken;
        if (token) {
            return auth_service_1.AuthService.verifyToken(token);
        }
    }
    catch (err) {
        logger_1.logger.warn({ err }, 'Socket authentication token failed verification');
    }
    // Fallback to null (allowing custom protocol identification messages e.g. register_driver to declare identity)
    return null;
}
