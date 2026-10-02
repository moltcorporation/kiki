import type { MetadataRoute } from "next";
import { site } from "@/lib/site";

/** Open to search and AI answer engines; the API is off limits. */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [{ userAgent: "*", allow: "/", disallow: ["/api/"] }],
    sitemap: `${site.url}/sitemap.xml`,
    host: site.url,
  };
}
