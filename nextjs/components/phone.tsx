import Image from "next/image";

/** A slim iPhone bezel. */
function Frame({ className = "", children }: { className?: string; children: React.ReactNode }) {
  return (
    <div
      className={`relative aspect-[1206/2622] w-[280px] shrink-0 overflow-hidden rounded-[46px] bg-[#0f1114] p-[7px] shadow-[0_40px_80px_-24px_rgba(0,0,0,0.85),0_0_0_1px_rgba(255,255,255,0.08)] sm:w-[300px] ${className}`}
    >
      <div className="relative size-full overflow-hidden rounded-[39px] bg-paper">{children}</div>
    </div>
  );
}

/** A real screenshot of the app in a phone frame. */
export function PhoneShot({
  src,
  alt,
  className,
  priority = false,
}: {
  src: string;
  alt: string;
  className?: string;
  priority?: boolean;
}) {
  return (
    <Frame className={className}>
      <Image src={src} alt={alt} fill sizes="300px" className="object-cover" priority={priority} />
    </Frame>
  );
}

/** The app's welcome screen: the running film with the pitch over it. */
export function WelcomePhone({ className }: { className?: string }) {
  return (
    <Frame className={className}>
      <div role="img" aria-label="Kiki's welcome screen: a runner at golden hour with “Your AI running coach.”" className="absolute inset-0">
        <video
          className="absolute inset-0 size-full object-cover"
          src="/welcome.mp4"
          poster="/welcome-poster.jpg"
          autoPlay
          muted
          loop
          playsInline
          preload="auto"
          aria-hidden
        />
        <div className="absolute inset-0 bg-gradient-to-b from-black/35 via-transparent via-35% to-black/90" />
        <div className="absolute left-1/2 top-3 h-7 w-24 -translate-x-1/2 rounded-full bg-black" />
        {/* eslint-disable-next-line @next/next/no-img-element -- tiny static asset */}
        <img src="/kiki-wordmark.png" alt="" aria-hidden className="absolute left-1/2 top-16 h-[24px] w-auto -translate-x-1/2" />
        <div className="absolute inset-x-5 bottom-7 text-center">
          <p className="text-[30px] font-black italic leading-[0.95] tracking-[-0.03em] text-white">
            Your AI
            <br />
            running coach.
          </p>
          <div className="mt-6 rounded-full bg-white py-3 text-center text-[14px] font-semibold text-[#0b0c0e]">
            Get started
          </div>
          <p className="mt-3 text-[11px] text-white/80">
            Already have an account? <span className="font-semibold text-white">Sign in</span>
          </p>
        </div>
      </div>
    </Frame>
  );
}
