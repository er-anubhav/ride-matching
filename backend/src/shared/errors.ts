export class AppError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly title: string,
    public readonly detail: string,
    public readonly type: string = 'about:blank',
    public readonly instance?: string
  ) {
    super(detail);
    Object.setPrototypeOf(this, new.target.prototype);
  }

  toRFC7807(instancePath?: string) {
    return {
      type: this.type,
      title: this.title,
      status: this.statusCode,
      detail: this.detail,
      instance: this.instance || instancePath,
    };
  }
}

export class BadRequestError extends AppError {
  constructor(detail: string, instance?: string) {
    super(400, 'Bad Request', detail, 'https://errors.mrrideo.com/bad-request', instance);
  }
}

export class UnauthorizedError extends AppError {
  constructor(detail: string, instance?: string) {
    super(401, 'Unauthorized', detail, 'https://errors.mrrideo.com/unauthorized', instance);
  }
}

export class ForbiddenError extends AppError {
  constructor(detail: string, instance?: string) {
    super(403, 'Forbidden', detail, 'https://errors.mrrideo.com/forbidden', instance);
  }
}

export class NotFoundError extends AppError {
  constructor(detail: string, instance?: string) {
    super(404, 'Not Found', detail, 'https://errors.mrrideo.com/not-found', instance);
  }
}

export class ConflictError extends AppError {
  constructor(detail: string, instance?: string) {
    super(409, 'Conflict', detail, 'https://errors.mrrideo.com/conflict', instance);
  }
}

export class InternalServerError extends AppError {
  constructor(detail: string = 'An unexpected error occurred', instance?: string) {
    super(500, 'Internal Server Error', detail, 'https://errors.mrrideo.com/internal-error', instance);
  }
}

export class TooManyRequestsError extends AppError {
  constructor(detail: string, instance?: string) {
    super(429, 'Too Many Requests', detail, 'https://errors.mrrideo.com/too-many-requests', instance);
  }
}
