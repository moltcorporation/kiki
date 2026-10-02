import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { DownloadCTA } from "@/components/site";
import { formatDate, guide, guides, type Block } from "@/lib/guides";
import { site } from "@/lib/site";

export function generateStaticParams() {
  return guides.map((g) => ({ slug: g.slug }));
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const g = guide((await params).slug);
  if (!g) return {};
  return {
    title: { absolute: `${g.seoTitle ?? g.title} · Kiki` },
    description: g.description,
    alternates: { canonical: `/guides/${g.slug}` },
    openGraph: { type: "article", title: g.seoTitle ?? g.title, description: g.description, modifiedTime: g.updated },
  };
}

function BlockView({ block }: { block: Block }) {
  switch (block.type) {
    case "h2":
      return <h2 className="pt-6 text-2xl font-semibold tracking-tight text-ink">{block.text}</h2>;
    case "p":
      return <p>{block.text}</p>;
    case "ul":
      return (
        <ul className="list-disc space-y-2 pl-5">
          {block.items.map((item) => <li key={item} className="pl-1">{item}</li>)}
        </ul>
      );
    case "ol":
      return (
        <ol className="list-decimal space-y-2 pl-5">
          {block.items.map((item) => <li key={item} className="pl-1">{item}</li>)}
        </ol>
      );
    case "tip":
      return (
        <p className="rounded-2xl border border-line bg-surface px-6 py-5 text-ink/90">
          <span className="font-semibold text-ink">Coach&apos;s tip: </span>
          {block.text}
        </p>
      );
    case "table":
      return (
        <div className="-mx-5 overflow-x-auto px-5 sm:mx-0 sm:px-0">
          <table className="w-full min-w-[480px] border-collapse text-left text-[15px]">
            {block.caption && <caption className="pb-3 text-left text-sm font-semibold text-subtle">{block.caption}</caption>}
            <thead>
              <tr className="border-b border-line">
                {block.head.map((h, i) => <th key={i} scope="col" className="py-3 pr-4 font-semibold text-ink">{h}</th>)}
              </tr>
            </thead>
            <tbody>
              {block.rows.map((row, i) => (
                <tr key={i} className="border-b border-line">
                  {row.map((cell, j) => <td key={j} className={`py-3 pr-4 ${j === 0 ? "font-medium text-ink" : ""}`}>{cell}</td>)}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      );
  }
}

export default async function GuidePage({ params }: { params: Promise<{ slug: string }> }) {
  const g = guide((await params).slug);
  if (!g) notFound();
  const url = `${site.url}/guides/${g.slug}`;
  const related = guides.filter((x) => x.slug !== g.slug).slice(0, 3);
  const jsonLd = [
    {
      "@context": "https://schema.org",
      "@type": "Article",
      headline: g.seoTitle ?? g.title,
      description: g.description,
      dateModified: g.updated,
      datePublished: g.updated,
      mainEntityOfPage: url,
      author: { "@type": "Organization", name: "Kiki", url: site.url },
      publisher: { "@type": "Organization", name: site.company, logo: { "@type": "ImageObject", url: `${site.url}/kiki-icon.png` } },
    },
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      itemListElement: [
        { "@type": "ListItem", position: 1, name: "Guides", item: `${site.url}/guides` },
        { "@type": "ListItem", position: 2, name: g.title, item: url },
      ],
    },
    {
      "@context": "https://schema.org",
      "@type": "FAQPage",
      mainEntity: g.faqs.map((f) => ({ "@type": "Question", name: f.q, acceptedAnswer: { "@type": "Answer", text: f.a } })),
    },
  ];

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <article className="mx-auto max-w-2xl px-5 py-16 sm:py-24">
        <nav aria-label="Breadcrumb" className="text-sm text-subtle">
          <Link href="/guides" className="hover:text-ink">Guides</Link> <span aria-hidden>/</span> {g.category}
        </nav>
        <h1 className="mt-5 text-balance text-4xl font-black italic leading-[0.98] tracking-[-0.03em] sm:text-[56px]">{g.title}</h1>
        <p className="mt-5 text-sm text-subtle">
          By the Kiki team · Updated <time dateTime={g.updated}>{formatDate(g.updated)}</time> · {g.minutes} min read
        </p>

        <p className="mt-10 border-l-2 border-[#CEFF00] pl-5 text-xl leading-relaxed text-ink">{g.answer}</p>

        <div className="mt-10 space-y-5 text-[17px] leading-relaxed text-muted">
          {g.blocks.map((block, i) => <BlockView key={i} block={block} />)}
        </div>

        <section className="mt-16">
          <h2 className="text-2xl font-semibold tracking-tight">Common questions</h2>
          <dl className="mt-6 space-y-6">
            {g.faqs.map((f) => (
              <div key={f.q}>
                <dt className="font-semibold text-ink">{f.q}</dt>
                <dd className="mt-2 leading-relaxed text-muted">{f.a}</dd>
              </div>
            ))}
          </dl>
        </section>

        <aside className="asphalt mt-16 overflow-hidden rounded-3xl border border-line p-8 sm:p-10">
          <h2 className="text-3xl font-black italic leading-tight tracking-[-0.03em]">Get a plan built for you.</h2>
          <p className="mt-3 max-w-md leading-relaxed text-muted">
            Kiki is an AI running coach for iPhone. It builds your plan around your goal and schedule, and adapts it as you go.
          </p>
          <div className="mt-8"><DownloadCTA /></div>
        </aside>

        <p className="mt-10 text-sm leading-relaxed text-subtle">
          This guide is general information, not medical advice. If you have pain, an injury or a health condition, talk to a qualified professional.
        </p>
      </article>

      <section className="border-t border-line">
        <div className="mx-auto max-w-6xl px-5 py-20">
          <h2 className="text-2xl font-semibold tracking-tight">More guides</h2>
          <div className="mt-6 grid gap-4 md:grid-cols-3">
            {related.map((r) => (
              <Link key={r.slug} href={`/guides/${r.slug}`} className="group rounded-3xl border border-line bg-surface p-7 transition-colors hover:border-ink/25">
                <p className="text-sm font-medium text-subtle">{r.category} · {r.minutes} min read</p>
                <h3 className="mt-3 text-lg font-semibold leading-snug group-hover:underline group-hover:underline-offset-4">{r.title}</h3>
              </Link>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
