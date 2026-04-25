import type { Metadata } from "next";
import { Outfit, DM_Sans } from "next/font/google";
import "./globals.css";
import { Navigation } from "@/components/Navigation";

const outfit = Outfit({
  variable: "--font-outfit",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
  display: "swap",
});

const dmSans = DM_Sans({
  variable: "--font-dm-sans",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "Swimmer Notes",
  description: "Training notes for focused swimming practice",
  icons: {
    icon: "/favicon.ico",
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
      className={`${outfit.variable} ${dmSans.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col relative">
        {/* Bubble particles background */}
        <div className="fixed inset-0 pointer-events-none z-0 overflow-hidden">
          {/* Floating bubbles */}
          <div className="absolute w-3 h-3 bg-white/30 rounded-full top-[10%] left-[5%] animate-[bubble-float_4s_ease-in-out_infinite]" />
          <div className="absolute w-4 h-4 bg-white/20 rounded-full top-[30%] left-[15%] animate-[bubble-float_5s_ease-in-out_infinite_0.5s]" />
          <div className="absolute w-2 h-2 bg-white/40 rounded-full top-[50%] left-[25%] animate-[bubble-float_3s_ease-in-out_infinite_1s]" />
          <div className="absolute w-5 h-5 bg-white/15 rounded-full top-[70%] right-[10%] animate-[bubble-float_6s_ease-in-out_infinite]" />
          <div className="absolute w-3 h-3 bg-white/25 rounded-full top-[20%] right-[30%] animate-[bubble-float_4s_ease-in-out_infinite_2s]" />
          <div className="absolute w-2 h-2 bg-white/35 rounded-full top-[60%] right-[20%] animate-[bubble-float_3s_ease-in-out_infinite_1.5s]" />
          <div className="absolute w-4 h-4 bg-white/20 rounded-full top-[85%] left-[40%] animate-[bubble-float_5s_ease-in-out_infinite_3s]" />
        </div>
        {/* Navigation */}
        <Navigation />
        {/* Main content */}
        <div className="relative z-10 flex-1">
          {children}
        </div>
      </body>
    </html>
  );
}