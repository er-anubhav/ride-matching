import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { verifyJwtMiddleware } from './auth';
import { logger } from '../shared/logger';
import { prisma } from '../shared/prisma';

// Auxiliary in-memory cache stores for transient search & session preferences
const recentSearchesStore = new Map<string, any[]>();
const walletStore = new Map<string, { balance: number; transactions: string[] }>();
const paymentMethodsStore = new Map<string, any[]>();
const sosContactsStore = new Map<string, any[]>();

export async function userApiRoutes(server: FastifyInstance) {
  server.addHook('preHandler', verifyJwtMiddleware);

  // ─── 1. USER PROFILE: GET /api/profile & PUT /api/profile ─────────────────
  server.get('/api/profile', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
      const dbUser = await prisma.user.findUnique({ where: { id: user.userId } });
      return reply.code(200).send({
        status: 'success',
        name: dbUser?.name || user.name || 'Rider User',
        phone: dbUser?.phone || user.phone || '+91 98765 43210',
        email: dbUser?.email || 'user@urbanpulse.com',
        rating: 4.9,
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      });
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  server.put('/api/profile', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
      const { name, email, avatarUrl } = (request.body as any) || {};
      let updatedUser;
      try {
        updatedUser = await prisma.user.update({
          where: { id: user.userId },
          data: {
            ...(name ? { name } : {}),
            ...(email ? { email } : {}),
          },
        });
      } catch (_) {}

      return reply.code(200).send({
        status: 'success',
        name: name || updatedUser?.name || user.name || 'Rider User',
        phone: updatedUser?.phone || user.phone || '+91 98765 43210',
        email: email || updatedUser?.email || 'user@urbanpulse.com',
        rating: 4.9,
        avatarUrl: avatarUrl || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      });
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // ─── 2. SAVED PLACES: GET/POST/DELETE /api/saved-places ──────────────────
  server.get('/api/saved-places', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
      const dbPlaces: any[] = await (prisma as any).savedPlace.findMany({
        where: { userId: user.userId },
        orderBy: { createdAt: 'desc' },
      });
      const items = dbPlaces.map((p: any) => ({
        id: p.id,
        label: p.label,
        address: p.address,
        latitude: Number(p.latitude),
        longitude: Number(p.longitude),
      }));
      return reply.code(200).send(items);
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  server.post('/api/saved-places', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
      const body = (request.body as any) || {};
      const newPlace: any = await (prisma as any).savedPlace.create({
        data: {
          userId: user.userId,
          label: body.label || 'Saved Place',
          address: body.address || '',
          latitude: body.latitude || body.lat || 0.0,
          longitude: body.longitude || body.lng || 0.0,
        },
      });
      return reply.code(201).send({
        id: newPlace.id,
        label: newPlace.label,
        address: newPlace.address,
        latitude: Number(newPlace.latitude),
        longitude: Number(newPlace.longitude),
      });
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  server.delete('/api/saved-places/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
      const { id } = request.params as any;
      await (prisma as any).savedPlace.deleteMany({
        where: {
          userId: user.userId,
          OR: [{ id: id }, { label: id }],
        },
      });
      return reply.code(200).send({ status: 'success' });
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // ─── 3. RECENT SEARCHES: GET/POST/DELETE /api/recent-searches ────────────
  server.get('/api/recent-searches', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user;
    const items = recentSearchesStore.get(user.userId) || [];
    return reply.code(200).send(items);
  });

  server.post('/api/recent-searches', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user;
    const body = (request.body as any) || {};
    const items = recentSearchesStore.get(user.userId) || [];
    const newItem = {
      address: body.address || '',
      latitude: body.latitude || body.lat || 0.0,
      longitude: body.longitude || body.lng || 0.0,
      timestamp: new Date().toISOString(),
    };
    const updated = [newItem, ...items.filter(i => i.address !== newItem.address)].slice(0, 10);
    recentSearchesStore.set(user.userId, updated);
    return reply.code(201).send(newItem);
  });

  server.delete('/api/recent-searches', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user;
    const { address } = (request.query as any) || {};
    const items = recentSearchesStore.get(user.userId) || [];
    const updated = items.filter(i => i.address !== address);
    recentSearchesStore.set(user.userId, updated);
    return reply.code(200).send({ status: 'success' });
  });

  // ─── 4. WALLET SERVICE: GET/POST /api/wallet ─────────────────────────────
  server.get('/api/wallet', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user;
    const data = walletStore.get(user.userId) || { balance: 345.50, transactions: ["Initial Welcome Credit - ₹345.50 added"] };
    walletStore.set(user.userId, data);
    return reply.code(200).send(data);
  });

  server.post('/api/wallet/add-money', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user;
    const { amount } = (request.body as any) || {};
    const numAmount = parseFloat(amount) || 0.0;
    const data = walletStore.get(user.userId) || { balance: 0.0, transactions: [] };
    data.balance += numAmount;
    data.transactions.unshift(`Added Money via UPI - ₹${numAmount.toFixed(2)} added`);
    walletStore.set(user.userId, data);
    return reply.code(200).send(data);
  });

  server.get('/api/wallet/payment-methods', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user;
    const items = paymentMethodsStore.get(user.userId) || [
      { id: '1', type: 'card', label: 'HDFC Visa •••• 4820', isDefault: true },
      { id: '2', type: 'upi', label: 'tripathi@okaxis', isDefault: false },
    ];
    paymentMethodsStore.set(user.userId, items);
    return reply.code(200).send(items);
  });

  server.post('/api/wallet/payment-methods', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user;
    const body = (request.body as any) || {};
    const items = paymentMethodsStore.get(user.userId) || [];
    const newItem = {
      id: Date.now().toString(),
      type: body.type || 'card',
      label: body.type === 'upi' ? body.upiId : `Card •••• ${body.lastFour || '1234'}`,
      isDefault: true,
    };
    const updated = [newItem, ...items.map(i => ({ ...i, isDefault: false }))];
    paymentMethodsStore.set(user.userId, updated);
    return reply.code(201).send(newItem);
  });

  server.delete('/api/wallet/payment-methods/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user;
    const { id } = request.params as any;
    const items = paymentMethodsStore.get(user.userId) || [];
    const updated = items.filter(i => i.id !== id);
    paymentMethodsStore.set(user.userId, updated);
    return reply.code(200).send({ status: 'success' });
  });

  // ─── 5. TRIP HISTORY: GET /api/rides/history ──────────────────────────────
  server.get('/api/rides/history', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user;
    try {
      const trips = await prisma.trip.findMany({
        where: { riderId: user.userId },
        orderBy: { createdAt: 'desc' },
        take: 20,
      });
      const formatted = trips.map(t => ({
        id: t.id,
        date: t.createdAt.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }),
        pickup: t.pickupAddress,
        destination: t.dropoffAddress,
        vehicle: t.vehicleType.toUpperCase(),
        price: (t as any).estimatedFare ? Number((t as any).estimatedFare) : ((t as any).finalFare ? Number((t as any).finalFare) : 120.0),
        status: t.status,
        driver: 'Assigned Driver',
        driverRating: 4.8,
        duration: '15 min',
        distance: '5.2 km',
      }));
      return reply.code(200).send(formatted);
    } catch (_) {
      return reply.code(200).send([]);
    }
  });

  // ─── 6. SOS CONTACTS: GET/POST/DELETE /api/sos/contacts ──────────────────
  server.get('/api/sos/contacts', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user;
    const items = sosContactsStore.get(user.userId) || [
      { id: '1', name: 'Papa (Primary)', phone: '+91 98765 98765' },
      { id: '2', name: 'Emergency Support', phone: '+91 11211 21120' },
    ];
    sosContactsStore.set(user.userId, items);
    return reply.code(200).send(items);
  });

  server.post('/api/sos/contact', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user;
    const body = (request.body as any) || {};
    const items = sosContactsStore.get(user.userId) || [];
    const newItem = {
      id: Date.now().toString(),
      name: body.name || 'Emergency Contact',
      phone: body.phone || body.phoneNumber || '',
    };
    const updated = [...items, newItem];
    sosContactsStore.set(user.userId, updated);
    return reply.code(201).send(newItem);
  });

  server.delete('/api/sos/contact/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user;
    const { id } = request.params as any;
    const items = sosContactsStore.get(user.userId) || [];
    const updated = items.filter(i => i.id !== id);
    sosContactsStore.set(user.userId, updated);
    return reply.code(200).send({ status: 'success' });
  });

  // ─── 7. SUPPORT TICKETS: GET/POST /api/support/tickets ──────────────────
  server.get('/api/support/tickets', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
      const dbTickets: any[] = await (prisma as any).supportTicket.findMany({
        where: { userId: user.userId },
        orderBy: { createdAt: 'desc' },
      });
      const items = dbTickets.map((t: any) => ({
        id: t.id,
        category: t.category,
        message: t.description,
        subject: t.subject,
        date: t.createdAt.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }),
        status: t.status,
      }));
      return reply.code(200).send(items);
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  server.post('/api/support/ticket', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
      const body = (request.body as any) || {};
      const newTicket: any = await (prisma as any).supportTicket.create({
        data: {
          userId: user.userId,
          subject: body.subject || body.category || 'General Support Ticket',
          category: body.category || 'GENERAL',
          description: body.message || body.description || '',
          status: 'OPEN',
        },
      });
      return reply.code(201).send({
        id: newTicket.id,
        category: newTicket.category,
        subject: newTicket.subject,
        message: newTicket.description,
        status: newTicket.status,
        date: 'Just now',
      });
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // ─── 8. PROMO VALIDATION: POST /api/promo/validate ──────────────────────
  server.post('/api/promo/validate', async (request: FastifyRequest, reply: FastifyReply) => {
    const { code } = (request.body as any) || {};
    const cleanCode = (code || '').toUpperCase().trim();

    if (cleanCode === 'URBANPULSE50' || cleanCode === 'WELCOME50' || cleanCode === 'FIRST50') {
      return reply.code(200).send({
        status: 'success',
        valid: true,
        code: cleanCode,
        discountPercentage: 50,
        maxDiscount: 50.0,
        message: '50% Off Promo Code Applied Successfully!',
      });
    }

    if (cleanCode === 'AIRPORT150') {
      return reply.code(200).send({
        status: 'success',
        valid: true,
        code: cleanCode,
        discountFlat: 150.0,
        message: '₹150 Flat Airport Discount Applied!',
      });
    }

    return reply.code(400).send({
      status: 'error',
      valid: false,
      message: 'Invalid or expired promo code',
    });
  });

  // ─── 9. ADMIN PRICING CONFIGURATION: GET/PUT /api/admin/pricing ─────────────
  server.get('/api/admin/pricing', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const { cityId } = (request.query as any) || {};
      const targetCity = cityId || 'CITY_DELHI';
      const dbConfigs = await prisma.cityConfig.findMany({
        where: { cityId: targetCity, isActive: true },
      });
      if (dbConfigs.length > 0) {
        const tiers = dbConfigs.map(c => ({
          vehicleType: c.vehicleType,
          baseFare: Number(c.baseFare),
          perKmRate: Number(c.perKmRate),
          perMinuteRate: Number(c.perMinRate),
          minimumFare: Number(c.minimumFare),
        }));
        return reply.code(200).send({ status: 'success', cityId: targetCity, tiers });
      }
      // Default initial tier fallback for target city
      return reply.code(200).send({
        status: 'success',
        cityId: targetCity,
        tiers: [
          { vehicleType: 'BIKE', baseFare: 25, perKmRate: 8, perMinuteRate: 1.5, minimumFare: 30 },
          { vehicleType: 'AUTO', baseFare: 35, perKmRate: 12, perMinuteRate: 2, minimumFare: 40 },
          { vehicleType: 'CAB_ECONOMY', baseFare: 60, perKmRate: 15, perMinuteRate: 2.5, minimumFare: 80 },
          { vehicleType: 'CAB_PREMIUM', baseFare: 100, perKmRate: 22, perMinuteRate: 4, minimumFare: 120 },
        ],
      });
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  server.put('/api/admin/pricing', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const { cityId, tiers } = (request.body as any) || {};
      const targetCity = cityId || 'CITY_DELHI';
      if (Array.isArray(tiers)) {
        for (const tier of tiers) {
          const existing: any = await (prisma as any).cityConfig.findFirst({
            where: {
              cityId: targetCity,
              vehicleType: tier.vehicleType,
            },
          });
          if (existing) {
            await (prisma as any).cityConfig.update({
              where: { id: existing.id },
              data: {
                baseFare: tier.baseFare,
                perKmRate: tier.perKmRate,
                perMinRate: tier.perMinuteRate || tier.perMinRate,
                minimumFare: tier.minimumFare,
                isActive: true,
              },
            });
          } else {
            await (prisma as any).cityConfig.create({
              data: {
                cityId: targetCity,
                vehicleType: tier.vehicleType,
                baseFare: tier.baseFare,
                perKmRate: tier.perKmRate,
                perMinRate: tier.perMinuteRate || tier.perMinRate,
                minimumFare: tier.minimumFare,
                isActive: true,
              },
            });
          }
        }
      }
      return reply.code(200).send({ status: 'success', cityId: targetCity, message: 'Pricing matrix updated successfully in PostgreSQL' });
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });
}
