import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title: 'مقابل | خذ اللي بدك إياه، مقابل اللي عندك', description: 'مساحة عربية لتبادل الإلكترونيات والكتب والألعاب. اكتشف غرضك القادم بدون كاش، واعرض ما لا تحتاجه للمقايضة.', icons: { icon: '/icon.svg' } };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="ar" dir="rtl"><body>{children}</body></html>; }
