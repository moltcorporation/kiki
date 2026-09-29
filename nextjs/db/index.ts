// DO NOT MODIFY — pre-configured database connection.
// Database client. Import in API routes: import { db } from "@/db";
// Query example: const rows = await db.select().from(posts);

import { neon } from "@neondatabase/serverless";
import { drizzle } from "drizzle-orm/neon-http";
import * as schema from "./schema";

const sql = neon(process.env.DATABASE_URL!);
export const db = drizzle(sql, { schema });