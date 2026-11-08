import { z } from 'zod';
import type { RevenueCatEventInput } from '../domain/subscription.js';

/** Loose schema: RevenueCat adds fields over time, so unknown keys are fine. */
const payloadSchema = z.object({
  event: z.object({
    id: z.string().min(1),
    type: z.string().min(1),
    app_user_id: z.string().min(1),
    aliases: z.array(z.string()).nullish(),
    original_app_user_id: z.string().nullish(),
    entitlement_ids: z.array(z.string()).nullish(),
    entitlement_id: z.string().nullish(),
    product_id: z.string().nullish(),
    store: z.string().nullish(),
    expiration_at_ms: z.number().nullish(),
    event_timestamp_ms: z.number(),
  }),
});

/** Returns null when the payload is not a RevenueCat webhook body. */
export function parseRevenueCatPayload(
  body: unknown,
): RevenueCatEventInput | null {
  const parsed = payloadSchema.safeParse(body);
  if (!parsed.success) return null;
  const e = parsed.data.event;
  const entitlementIds =
    e.entitlement_ids ?? (e.entitlement_id ? [e.entitlement_id] : null);
  return {
    id: e.id,
    type: e.type,
    appUserId: e.app_user_id,
    aliases: [
      ...(e.aliases ?? []),
      ...(e.original_app_user_id ? [e.original_app_user_id] : []),
    ],
    entitlementIds,
    productId: e.product_id ?? null,
    store: e.store ?? null,
    expirationAt: e.expiration_at_ms ? new Date(e.expiration_at_ms) : null,
    eventAt: new Date(e.event_timestamp_ms),
  };
}
