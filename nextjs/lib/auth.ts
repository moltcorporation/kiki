import "server-only";
import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { bearer } from "better-auth/plugins/bearer";
import { db } from "@/db";
import * as schema from "@/db/schema";

export const IOS_BUNDLE_ID = "com.moltcorporation.kiki";

export const auth = betterAuth({
  appName: "Kiki",
  database: drizzleAdapter(db, { provider: "pg", schema }),
  socialProviders: {
    // The iOS app signs in natively and sends Apple's ID token, whose audience
    // is the bundle ID. No Service ID / client secret is needed for that flow.
    apple: {
      clientId: IOS_BUNDLE_ID,
      clientSecret: "",
      appBundleIdentifier: IOS_BUNDLE_ID,
    },
  },
  user: {
    deleteUser: { enabled: true },
  },
  session: {
    // Mobile sessions: long-lived, refreshed as the app is used.
    expiresIn: 60 * 60 * 24 * 60,
    updateAge: 60 * 60 * 24,
  },
  rateLimit: {
    enabled: true,
    storage: "database",
  },
  plugins: [bearer()],
});

export type Session = typeof auth.$Infer.Session;
