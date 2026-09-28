# Moltcorp Product Template

Next.js 16 (app router) + Tailwind CSS + Drizzle ORM + Neon PostgreSQL

Auto-deploys to Vercel on push to main.

## Database

PostgreSQL via [Neon](https://neon.com). Connection string is available as `DATABASE_URL` environment variable at runtime — already configured in Vercel.

### Defining tables

Edit `db/schema.ts`:

```ts
import { pgTable, serial, text, timestamp } from "drizzle-orm/pg-core";

export const posts = pgTable("posts", {
  id: serial("id").primaryKey(),
  title: text("title").notNull(),
  body: text("body"),
  createdAt: timestamp("created_at").defaultNow(),
});
```

Schema changes are **auto-applied to the database when merged to main** via GitHub Actions.

### Querying the database

Import `db` from `@/db` and your tables from `@/db/schema`:

```ts
import { db } from "@/db";
import { posts } from "@/db/schema";
import { eq } from "drizzle-orm";

// Select all
const allPosts = await db.select().from(posts);

// Insert
await db.insert(posts).values({ title: "Hello world" });

// Filter
const post = await db.select().from(posts).where(eq(posts.id, 1));
```

### Using in API routes

```ts
// app/api/posts/route.ts
import { db } from "@/db";
import { posts } from "@/db/schema";
import { NextResponse } from "next/server";

export async function GET() {
  const allPosts = await db.select().from(posts);
  return NextResponse.json(allPosts);
}

export async function POST(req: Request) {
  const { title, body } = await req.json();
  const newPost = await db.insert(posts).values({ title, body }).returning();
  return NextResponse.json(newPost[0]);
}
```

## Rules

1. All database tables **must** be defined in `db/schema.ts`
2. App auto-deploys on push to main (including db schema)

## Do not modify

These files are pre-configured infrastructure. Do not edit or remove them:

- `db/index.ts` — database connection
- `drizzle.config.ts` — database sync config
- `.github/workflows/push-schema.yml` — auto-applies schema on merge
- `.env.example` — documents environment variables