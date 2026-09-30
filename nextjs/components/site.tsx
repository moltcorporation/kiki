import Link from "next/link";
import { site } from "@/lib/site";

/** The app icon artwork (same file as the iOS icon, `public/kiki-icon.png`). */
export function LogoMark({ className = "size-8" }: { className?: string }) {
  return (
    // eslint-disable-next-line @next/next/no-img-element -- tiny static asset, no optimization needed
    <img src="/kiki-icon.png" alt="" aria-hidden className={`rounded-[22.5%] ${className}`} />
  );
}

export function Logo() {
  return (
    <Link href="/" className="flex items-center gap-2.5 text-lg" aria-label="Kiki home">
      <LogoMark className="size-9" />
      {/* eslint-disable-next-line @next/next/no-img-element -- tiny static asset */}
      <img src="/kiki-wordmark.png" alt="" aria-hidden className="h-[22px] w-auto" />
    </Link>
  );
}

export function DownloadButton({ inverted = false }: { inverted?: boolean }) {
  const styles = inverted
    ? "bg-paper text-ink hover:bg-white/90"
    : "bg-ink text-paper hover:bg-ink/85";
  const className = `inline-flex h-14 items-center justify-center gap-2 rounded-full px-8 text-[17px] font-semibold transition-colors focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-current ${styles}`;

  if (!site.appStoreUrl) {
    return (
      <span className={className} aria-disabled>
        Coming soon to iPhone
      </span>
    );
  }
  return (
    <a href={site.appStoreUrl} className={className}>
      Get Kiki for iPhone
    </a>
  );
}

export function Header() {
  return (
    <header className="sticky top-0 z-50 border-b border-line/70 bg-paper/80 backdrop-blur-xl">
      <nav className="mx-auto flex h-16 max-w-6xl items-center justify-between px-5">
        <Logo />
        <div className="flex items-center gap-7 text-[15px] font-medium text-muted">
          <Link href="/#how" className="hidden hover:text-ink sm:inline">How it works</Link>
          <Link href="/#pricing" className="hidden hover:text-ink sm:inline">Pricing</Link>
          <Link href="/#faq" className="hidden hover:text-ink sm:inline">FAQ</Link>
          {site.appStoreUrl && (
            <a
              href={site.appStoreUrl}
              className="rounded-full bg-ink px-4 py-2 text-sm font-semibold text-paper hover:bg-ink/85"
            >
              Download
            </a>
          )}
        </div>
      </nav>
    </header>
  );
}

export function Footer() {
  return (
    <footer className="border-t border-line">
      <div className="mx-auto flex max-w-6xl flex-col gap-8 px-5 py-12 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex flex-col gap-3">
          <Logo />
          <p className="text-sm text-subtle">
            © {new Date().getFullYear()} {site.company}
          </p>
        </div>
        <div className="flex flex-wrap gap-x-7 gap-y-3 text-[15px] text-muted">
          <Link href="/privacy" className="hover:text-ink">Privacy</Link>
          <Link href="/terms" className="hover:text-ink">Terms</Link>
          <Link href="/support" className="hover:text-ink">Support</Link>
          <a href={`mailto:${site.supportEmail}`} className="hover:text-ink">Contact</a>
        </div>
      </div>
    </footer>
  );
}
