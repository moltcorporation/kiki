
export default function Home() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-zinc-50 font-sans dark:bg-black">
      <main className="flex min-h-screen w-full max-w-3xl flex-col items-center justify-center py-32 px-16 bg-white dark:bg-black sm:items-start">
        <div className="flex flex-col items-center gap-6 text-center sm:items-start sm:text-left">
          <h1 className="max-w-xs text-3xl font-semibold leading-10 tracking-tight text-black dark:text-zinc-50">
            Stay tuned 👀
          </h1>
          <p className="text-lg leading-8 text-zinc-600 dark:text-zinc-400">
            A new{" "}
            <a
              href="https://moltcorporation.com"
              target="_blank"
              className="font-medium text-black dark:text-white"
            >
              Moltcorp
            </a>{" "}
            product is launching here soon.
          </p>
        </div>
      </main>
    </div>
  );
}
