import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Majoor — A voice-first assistant for your Mac",
  description:
    "Hold Ctrl+Option, speak, get things done. A Dynamic-Island-style menu-bar assistant for macOS — open apps, navigate sites, answer questions, control your system. Free and open source.",
  metadataBase: new URL("https://majoor.vercel.app"),
  openGraph: {
    title: "Majoor",
    description: "A voice-first menu-bar assistant for macOS. Hold ⌃⌥, speak, get things done.",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Majoor",
    description: "A voice-first menu-bar assistant for macOS. Hold ⌃⌥, speak, get things done.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased dark`}
    >
      <body className="min-h-full bg-[#06060a] text-white selection:bg-cyan-400/30">
        {children}
      </body>
    </html>
  );
}
