import type { Metadata } from "next";
import "./styles.css";

export const metadata: Metadata = {
  title: "Atlas Settlement",
  description: "Institutional tokenized asset settlement and custody dashboard"
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}

