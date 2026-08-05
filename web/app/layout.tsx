import "@/styles/globals.css";
import { Metadata, Viewport } from "next";

import { Providers } from "./providers";

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000"),
  title: "MediTrace — Medication level tracker",
  description: "Record medication doses, estimate levels over time, and create reminders.",
  icons: {
    icon: "/favicon.ico",
  },
  openGraph: {
    title: "MediTrace",
    description: "Record doses. Understand the trend.",
    images: [{ url: "/og.png", width: 1200, height: 630, alt: "MediTrace medication trend dashboard" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "MediTrace",
    description: "Record doses. Understand the trend.",
    images: ["/og.png"],
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f4f7f5" },
    { media: "(prefers-color-scheme: dark)", color: "#101613" },
  ],
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html suppressHydrationWarning lang="en">
      <head />
      <body className="min-h-screen text-foreground bg-background font-sans antialiased">
        <Providers themeProps={{ attribute: "class", defaultTheme: "system", enableSystem: true }}>
          {children}
        </Providers>
      </body>
    </html>
  );
}
