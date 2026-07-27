export declare class AppError extends Error {
    readonly statusCode: number;
    readonly title: string;
    readonly detail: string;
    readonly type: string;
    readonly instance?: string | undefined;
    constructor(statusCode: number, title: string, detail: string, type?: string, instance?: string | undefined);
    toRFC7807(instancePath?: string): {
        type: string;
        title: string;
        status: number;
        detail: string;
        instance: string | undefined;
    };
}
export declare class BadRequestError extends AppError {
    constructor(detail: string, instance?: string);
}
export declare class UnauthorizedError extends AppError {
    constructor(detail: string, instance?: string);
}
export declare class ForbiddenError extends AppError {
    constructor(detail: string, instance?: string);
}
export declare class NotFoundError extends AppError {
    constructor(detail: string, instance?: string);
}
export declare class ConflictError extends AppError {
    constructor(detail: string, instance?: string);
}
export declare class InternalServerError extends AppError {
    constructor(detail?: string, instance?: string);
}
export declare class TooManyRequestsError extends AppError {
    constructor(detail: string, instance?: string);
}
