// DO NOT MODIFY — used by GitHub Actions to sync db/schema.ts to the database on merge.
// This runs automatically via GitHub Actions on merge. No manual setup needed.

import { defineConfig } from "drizzle-kit";

export default defineConfig({
    dialect: "postgresql",
    schema: "./db/schema.ts",
    dbCredentials: {
        url: process.env.DATABASE_URL!,
    },
});
