import "server-only";
import { PostHog } from "posthog-node";

const token = process.env.NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN;

if (!token && process.env.NODE_ENV === "development") {
  throw new Error(
    "NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN variable required by PostHog is missing or un-configured, this causes events to be silently missed. This error stops appearing once NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN is configured",
  );
}

const client = token
  ? new PostHog(token, {
      host: process.env.NEXT_PUBLIC_POSTHOG_HOST ?? "https://us.i.posthog.com",
      flushAt: 1,
      flushInterval: 0,
    })
  : null;

/** Reports a server error to PostHog error tracking (no-op without a token). */
export async function captureServerError(
  error: unknown,
  userId?: string,
  properties?: Record<string, unknown>,
) {
  if (!client) return;
  try {
    await client.captureExceptionImmediate(error, userId, properties);
  } catch {
    // Never let telemetry failures affect the response.
  }
}
