"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TooManyRequestsError = exports.InternalServerError = exports.ConflictError = exports.NotFoundError = exports.ForbiddenError = exports.UnauthorizedError = exports.BadRequestError = exports.AppError = void 0;
class AppError extends Error {
    statusCode;
    title;
    detail;
    type;
    instance;
    constructor(statusCode, title, detail, type = 'about:blank', instance) {
        super(detail);
        this.statusCode = statusCode;
        this.title = title;
        this.detail = detail;
        this.type = type;
        this.instance = instance;
        Object.setPrototypeOf(this, new.target.prototype);
    }
    toRFC7807(instancePath) {
        return {
            type: this.type,
            title: this.title,
            status: this.statusCode,
            detail: this.detail,
            instance: this.instance || instancePath,
        };
    }
}
exports.AppError = AppError;
class BadRequestError extends AppError {
    constructor(detail, instance) {
        super(400, 'Bad Request', detail, 'https://errors.mrrideo.com/bad-request', instance);
    }
}
exports.BadRequestError = BadRequestError;
class UnauthorizedError extends AppError {
    constructor(detail, instance) {
        super(401, 'Unauthorized', detail, 'https://errors.mrrideo.com/unauthorized', instance);
    }
}
exports.UnauthorizedError = UnauthorizedError;
class ForbiddenError extends AppError {
    constructor(detail, instance) {
        super(403, 'Forbidden', detail, 'https://errors.mrrideo.com/forbidden', instance);
    }
}
exports.ForbiddenError = ForbiddenError;
class NotFoundError extends AppError {
    constructor(detail, instance) {
        super(404, 'Not Found', detail, 'https://errors.mrrideo.com/not-found', instance);
    }
}
exports.NotFoundError = NotFoundError;
class ConflictError extends AppError {
    constructor(detail, instance) {
        super(409, 'Conflict', detail, 'https://errors.mrrideo.com/conflict', instance);
    }
}
exports.ConflictError = ConflictError;
class InternalServerError extends AppError {
    constructor(detail = 'An unexpected error occurred', instance) {
        super(500, 'Internal Server Error', detail, 'https://errors.mrrideo.com/internal-error', instance);
    }
}
exports.InternalServerError = InternalServerError;
class TooManyRequestsError extends AppError {
    constructor(detail, instance) {
        super(429, 'Too Many Requests', detail, 'https://errors.mrrideo.com/too-many-requests', instance);
    }
}
exports.TooManyRequestsError = TooManyRequestsError;
