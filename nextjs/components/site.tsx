import Link from "next/link";
import { site } from "@/lib/site";

export function Logo() {
  return (
    <Link href="/" className="flex items-center gap-2.5 text-lg" aria-label="Kiki home">
      {/* eslint-disable-next-line @next/next/no-img-element -- tiny static asset */}
      <img src="/kiki-wordmark.png" alt="" aria-hidden className="h-[22px] w-auto" />
    </Link>
  );
}

/** Apple's official "Download on the App Store" badge, linking to Kiki. */
export function AppStoreBadge({ size = "lg" }: { size?: "sm" | "lg" }) {
  return (
    <a
      href={site.appStoreUrl}
      className="inline-block shrink-0 rounded-[10px] transition-opacity hover:opacity-85 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-ink"
      aria-label="Download Kiki on the App Store"
    >
      {/* eslint-disable-next-line @next/next/no-img-element -- Apple's badge artwork, unmodified */}
      <img
        src="/app-store-badge.svg"
        alt="Download on the App Store"
        className={size === "lg" ? "h-[54px] w-auto" : "h-10 w-auto"}
      />
    </a>
  );
}

/** The App Store badge with a small note under it. */
export function DownloadCTA({ center = false }: { center?: boolean }) {
  return (
    <div className={`flex flex-col gap-3 ${center ? "items-center" : "items-start"}`}>
      <AppStoreBadge />
      <p className="text-sm text-subtle">Free to download · For iPhone</p>
    </div>
  );
}

const nav = [
  { href: "/#features", label: "Features" },
  { href: "/#how", label: "How it works" },
  { href: "/guides", label: "Guides" },
  { href: "/#faq", label: "FAQ" },
];

export function Header() {
  return (
    <header className="sticky top-0 z-50 border-b border-line bg-paper/70 backdrop-blur-xl">
      <nav className="mx-auto flex h-16 max-w-6xl items-center justify-between px-5" aria-label="Main">
        <Logo />
        <div className="flex items-center gap-7 text-[15px] font-medium text-muted">
          {nav.map((item) => (
            <Link key={item.href} href={item.href} className="hidden hover:text-ink md:inline">
              {item.label}
            </Link>
          ))}
          <a
            href={site.appStoreUrl}
            className="rounded-full bg-ink px-4 py-2 text-sm font-semibold text-paper transition-colors hover:bg-ink/90"
          >
            Download
          </a>
        </div>
      </nav>
    </header>
  );
}

export function Footer() {
  const columns = [
    {
      title: "Kiki",
      links: [
        { href: "/#features", label: "Features" },
        { href: "/#how", label: "How it works" },
        { href: "/#faq", label: "FAQ" },
        { href: site.appStoreUrl, label: "Download for iPhone" },
      ],
    },
    {
      title: "Guides",
      links: [
        { href: "/guides/how-to-start-running", label: "How to start running" },
        { href: "/guides/couch-to-5k", label: "Couch to 5K" },
        { href: "/guides/half-marathon-training-plan", label: "Half marathon training" },
        { href: "/guides/marathon-training-for-beginners", label: "Marathon training" },
        { href: "/guides", label: "All guides" },
      ],
    },
    {
      title: "Company",
      links: [
        { href: "/support", label: "Support" },
        { href: "/privacy", label: "Privacy" },
        { href: "/terms", label: "Terms" },
        { href: `mailto:${site.supportEmail}`, label: "Contact" },
      ],
    },
  ];

  return (
    <footer className="border-t border-line">
      <div className="mx-auto grid max-w-6xl gap-12 px-5 py-16 md:grid-cols-[1.4fr_repeat(3,1fr)]">
        <div className="flex flex-col items-start gap-5">
          <Logo />
          <p className="max-w-xs text-[15px] leading-relaxed text-muted">
            The AI running coach that builds your plan and adapts it as you go.
          </p>
          <AppStoreBadge size="sm" />
        </div>
        {columns.map((column) => (
          <div key={column.title}>
            <h2 className="text-sm font-semibold text-ink">{column.title}</h2>
            <ul className="mt-4 space-y-3 text-[15px] text-muted">
              {column.links.map((link) => (
                <li key={link.label}>
                  {link.href.startsWith("/") ? (
                    <Link href={link.href} className="hover:text-ink">{link.label}</Link>
                  ) : (
                    <a href={link.href} className="hover:text-ink">{link.label}</a>
                  )}
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
      <div className="mx-auto max-w-6xl border-t border-line px-5 py-8 text-sm text-subtle">
        © {new Date().getFullYear()} {site.company}. Kiki is a training tool, not medical advice.
      </div>
    </footer>
  );
}
