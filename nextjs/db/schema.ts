// Source of truth for the database schema.
// Edit this file to add or modify tables.
// Changes are auto-applied to the database when merged to main.
//
// Example:
//   export const posts = pgTable("posts", {
//     id: serial("id").primaryKey(),
//     title: text("title").notNull(),
//     createdAt: timestamp("created_at").defaultNow(),
//   });

// eslint-disable-next-line @typescript-eslint/no-unused-vars
import { pgTable, serial, text, timestamp } from "drizzle-orm/pg-core";