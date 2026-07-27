import { FastifyRequest } from 'fastify';
export declare const activeRiderSubscriptions: Map<string, {
    socket: any;
    lat: number;
    lng: number;
}>;
export declare function handleWebSocketConnection(connection: any, request: FastifyRequest): Promise<void>;
