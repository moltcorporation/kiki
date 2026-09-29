import "server-only";
import { z } from "zod";
import { auth } from "@/lib/auth";
import { captureServerError } from "@/lib/posthog-server";

export type AuthedUser = { id: string; email: string; name: string };

export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
  ) {
    super(message);
  }
}

export const notFound = () => new ApiError(404, "not_found", "Not found");

/**
 * Wraps a route handler with bearer/cookie authentication and consistent JSON
 * errors: `{ error: { code, message } }`.
 */
export function withUser<C>(
  handler: (req: Request, user: AuthedUser, ctx: C) => Promise<Response>,
) {
  return async (req: Request, ctx: C) => {
    let userId: string | undefined;
    try {
      const session = await auth.api.getSession({ headers: req.headers });
      if (!session) throw new ApiError(401, "unauthorized", "Sign in required");
      userId = session.user.id;
      return await handler(req, session.user, ctx);
    } catch (error) {
      if (error instanceof ApiError) {
        return Response.json(
          { error: { code: error.code, message: error.message } },
          { status: error.status },
        );
      }
      if (error instanceof z.ZodError) {
        return Response.json(
          { error: { code: "invalid_request", message: z.prettifyError(error) } },
          { status: 400 },
        );
      }
      console.error(error);
      await captureServerError(error, userId, { path: new URL(req.url).pathname });
      return Response.json(
        { error: { code: "internal", message: "Something went wrong" } },
        { status: 500 },
      );
    }
  };
}

export async function parseBody<T extends z.ZodType>(req: Request, schema: T) {
  const body = await req.json().catch(() => {
    throw new ApiError(400, "invalid_json", "Request body must be JSON");
  });
  return schema.parse(body) as z.infer<T>;
}

/** Validates a UUID path param, treating malformed IDs as not found. */
export function uuidParam(id: string) {
  if (!z.uuid().safeParse(id).success) throw notFound();
  return id;
}
