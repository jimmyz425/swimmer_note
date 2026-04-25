'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useRef } from 'react';
import { Home, History, Wrench, Waves } from 'lucide-react';

export function Navigation() {
  const pathname = usePathname();
  const navRef = useRef<HTMLElement>(null);

  // Update content padding based on actual nav height
  useEffect(() => {
    if (navRef.current) {
      const navHeight = navRef.current.offsetHeight;
      // Set CSS custom property for content padding
      document.documentElement.style.setProperty('--nav-height', `${navHeight}px`);
    }
  }, []);

  const links = [
    { href: '/', label: 'Home', icon: Home, lane: '1' },
    { href: '/history', label: 'History', icon: History, lane: '2' },
    { href: '/tools', label: 'Tools', icon: Wrench, lane: '3' },
  ];

  return (
    <header ref={navRef} className="bg-white border-b border-pool-light/30 px-4 md:px-6 py-3 flex items-center justify-between fixed top-0 left-0 right-0 z-20 safe-top">
      {/* Logo - Lane marker style */}
      <Link href="/" className="flex items-center gap-3 group">
        {/* Lane badge */}
        <div className="lane-badge w-9 h-9 flex items-center justify-center text-sm">
          <Waves className="w-4 h-4" />
        </div>

        {/* App name */}
        <span className="font-heading text-lg font-bold text-pool-dark uppercase tracking-wide group-hover:text-accent transition-colors">
          SWIMMER NOTES
        </span>
      </Link>

      {/* Nav links */}
      <nav className="flex items-center gap-1">
        {links.map((link) => {
          const isActive = pathname === link.href || pathname.startsWith(link.href + '/');
          const Icon = link.icon;

          return (
            <Link
              key={link.href}
              href={link.href}
              className={`flex items-center gap-2 px-4 py-2 rounded-lg font-heading font-medium transition-all duration-200
                ${isActive
                  ? 'bg-pool-mid/15 text-pool-dark nav-link active'
                  : 'text-pool-mid hover:text-pool-dark hover:bg-pool-surface nav-link'
                }`}
            >
              {/* Label */}
              <span className="text-sm uppercase tracking-wide">{link.label}</span>

              {/* Icon */}
              <Icon className="w-4 h-4" />
            </Link>
          );
        })}
      </nav>
    </header>
  );
}