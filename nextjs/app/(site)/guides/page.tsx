import type { Metadata } from "next";
import Link from "next/link";
import { DownloadCTA } from "@/components/site";
import { guides } from "@/lib/guides";

export const metadata: Metadata = {
  title: "Running guides",
  description:
    "Free, practical running guides from Kiki: how to start running, couch to 5K, half marathon and marathon training, easy pace and more.",
  alternates: { canonical: "/guides" },
};

export default function GuidesPage() {
  const categories = [...new Set(guides.map((g) => g.category))];
  return (
    <>
      <section className="asphalt -mt-16 pt-16">
        <div className="mx-auto max-w-6xl px-5 pb-20 pt-16 sm:pt-24">
          <h1 className="text-5xl font-black italic leading-[0.92] tracking-[-0.04em] sm:text-7xl">Running guides</h1>
          <p className="mt-6 max-w-xl text-lg leading-relaxed text-muted">
            Practical, no-jargon advice for every runner, from your first run to your first marathon.
          </p>
        </div>
      </section>
      <div className="mx-auto max-w-6xl space-y-16 px-5 py-20">
        {categories.map((category) => (
          <section key={category}>
            <h2 className="text-2xl font-semibold tracking-tight">{category}</h2>
            <div className="mt-6 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              {guides
                .filter((g) => g.category === category)
                .map((g) => (
                  <Link
                    key={g.slug}
                    href={`/guides/${g.slug}`}
                    className="group rounded-3xl border border-line bg-surface p-8 transition-colors hover:border-ink/25"
                  >
                    <p className="text-sm font-medium text-subtle">{g.minutes} min read</p>
                    <h3 className="mt-3 text-xl font-semibold leading-snug group-hover:underline group-hover:underline-offset-4">{g.title}</h3>
                    <p className="mt-3 line-clamp-3 leading-relaxed text-muted">{g.description}</p>
                  </Link>
                ))}
            </div>
          </section>
        ))}
      </div>
      <section className="border-t border-line">
        <div className="mx-auto flex max-w-6xl flex-col items-start justify-between gap-8 px-5 py-20 md:flex-row md:items-center">
          <div>
            <h2 className="text-3xl font-black italic tracking-[-0.03em] sm:text-4xl">Want a plan built for you?</h2>
            <p className="mt-3 max-w-md text-muted">Kiki turns these principles into your own day-by-day plan, and adapts it as you go.</p>
          </div>
          <DownloadCTA />
        </div>
      </section>
    </>
  );
}
