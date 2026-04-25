'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Home, History, Wrench } from 'lucide-react';

export function Navigation() {
  const pathname = usePathname();

  const links = [
    { href: '/', label: 'Home', icon: Home },
    { href: '/history', label: 'History', icon: History },
    { href: '/tools', label: 'Tools', icon: Wrench },
  ];

  return (
    <header className="glass-card shadow-sm px-6 py-3 flex items-center justify-between sticky top-0 z-20">
      {/* Logo */}
      <Link href="/" className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-pool-mid/20 flex items-center justify-center">
          <svg className="w-5 h-5 text-pool-deep" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M2 12C2 6 6 2 12 2C18 2 22 6 22 12C22 18 18 22 12 22C6 22 2 18 2 12Z" strokeLinecap="round"/>
            <path d="M8 12C8 10 10 8 12 8C14 8 16 10 16 12" strokeLinecap="round"/>
          </svg>
        </div>
        <span className="text-lg font-bold text-pool-dark">Swimmer Notes</span>
      </Link>

      {/* Nav links */}
      <nav className="flex items-center gap-2">
        {links.map((link) => {
          const isActive = pathname === link.href || pathname.startsWith(link.href + '/');
          const Icon = link.icon;

          return (
            <Link
              key={link.href}
              href={link.href}
              className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-all duration-200 ${
                isActive
                  ? 'bg-pool-mid/20 text-pool-dark'
                  : 'text-pool-mid hover:bg-pool-light/50 hover:text-pool-dark'
              }`}
            >
              <Icon className="w-4 h-4" />
              <span className="text-sm">{link.label}</span>
            </Link>
          );
        })}
      </nav>
    </header>
  );
}