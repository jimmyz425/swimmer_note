'use client';

import { useRouter } from 'next/navigation';
import { Waves, ArrowRight, Sparkles, Compass } from 'lucide-react';

interface StrokeCardProps {
  id: string;
  name: string;
  aliases: string[];
  laneNumber?: number;
}

// Stroke-specific icons
const strokeIcons: Record<string, React.ReactNode> = {
  freestyle: <svg className="w-8 h-8" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M4 12c0-4 4-8 8-8s8 4 8 8-4 8-8 8"/><path d="M8 12c0-2 2-4 4-4s4 2 4 4"/></svg>,
  backstroke: <svg className="w-8 h-8" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 4c4 0 8 4 8 8"/><path d="M4 12c0 4 4 8 8 8"/><path d="M8 12h8"/></svg>,
  breaststroke: <svg className="w-8 h-8" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="8" r="4"/><path d="M8 16c0 2 2 4 4 4s4-2 4-4"/></svg>,
  butterfly: <svg className="w-8 h-8" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M4 8c2 0 4 2 4 4"/><path d="M20 8c-2 0-4 2-4 4"/><path d="M8 16h8"/><path d="M12 4v4"/></svg>,
  im: <svg className="w-8 h-8" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M4 8h16M4 12h16M4 16h16"/><circle cx="8" cy="8" r="1" fill="currentColor"/><circle cx="16" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="16" r="1" fill="currentColor"/></svg>,
};

export function StrokeCard({ id, name, aliases, laneNumber = 1 }: StrokeCardProps) {
  const router = useRouter();

  const handleClick = () => {
    router.push(`/trees/${id}`);
  };

  const icon = strokeIcons[id] || <Waves className="w-8 h-8" />;

  return (
    <button
      onClick={handleClick}
      className="group relative glass-card rounded-xl p-5 flex flex-col items-center justify-center
        min-h-[150px] transition-all duration-300
        hover:shadow-xl hover:-translate-y-2 hover:bg-white/95
        ripple-container overflow-hidden"
    >
      {/* Lane number badge */}
      <div className="absolute top-3 right-3 w-8 h-8 bg-pool-mid/20 rounded-full text-xs font-bold flex items-center justify-center
        text-pool-dark transition-transform group-hover:scale-110 group-hover:bg-pool-mid/40">
        {laneNumber}
      </div>

      {/* Hover ripple effect */}
      <div className="absolute inset-0 bg-gradient-radial from-white/40 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300" />

      {/* Stroke icon */}
      <div className="relative mb-4 text-pool-deep transition-all duration-300 group-hover:text-pool-mid group-hover:scale-125">
        {icon}
      </div>

      {/* Stroke name */}
      <h3 className="font-bold text-pool-dark text-lg text-center">
        {name}
      </h3>

      {/* Alias/nickname */}
      {aliases.length > 0 && (
        <p className="text-xs text-pool-mid mt-1 font-medium">
          {aliases[0]}
        </p>
      )}

      {/* View Tree indicator */}
      <div className="mt-4 flex items-center gap-2 text-sm font-semibold text-pool-deep
        bg-pool-surface/80 px-4 py-2 rounded-full transition-all duration-300
        group-hover:bg-pool-mid group-hover:text-white group-hover:scale-105">
        <span>View Tree</span>
        <ArrowRight className="w-4 h-4 transition-transform group-hover:translate-x-1" />
      </div>

      {/* Bottom accent line */}
      <div className="absolute bottom-0 left-6 right-6 h-1.5 bg-gradient-to-r from-pool-light via-pool-mid to-pool-deep rounded-full
        opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
    </button>
  );
}

interface MasterTreeCardProps {
  onClick?: () => void;
}

export function MasterTreeCard({ onClick }: MasterTreeCardProps) {
  const router = useRouter();

  const handleClick = () => {
    if (onClick) {
      onClick();
    } else {
      router.push('/trees/master');
    }
  };

  return (
    <button
      onClick={handleClick}
      className="group relative glass-card rounded-xl p-6 flex items-center gap-5 w-full
        transition-all duration-300 hover:shadow-xl hover:-translate-y-1
        ripple-container overflow-hidden"
    >
      {/* Gradient background */}
      <div className="absolute inset-0 bg-gradient-to-r from-pool-surface/50 via-pool-light/30 to-pool-mid/20 opacity-80" />
      <div className="absolute inset-0 bg-gradient-radial from-white/30 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />

      {/* Master icon */}
      <div className="relative z-10 flex-shrink-0">
        <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-amber-400 to-orange-500
          flex items-center justify-center shadow-lg shadow-amber-400/30 transition-transform duration-300 group-hover:scale-110">
          <Sparkles className="w-7 h-7 text-white" />
        </div>
      </div>

      {/* Content */}
      <div className="relative z-10 flex-1 text-left">
        <h3 className="font-bold text-xl text-pool-dark">
          Master Techniques
        </h3>
        <p className="text-sm text-pool-mid font-medium mt-1">
          Core skills for all strokes: streamline, kicks, turns
        </p>
      </div>

      {/* Arrow indicator */}
      <div className="relative z-10 flex items-center gap-2 text-pool-deep font-semibold
        transition-transform duration-300 group-hover:translate-x-2">
        <span className="hidden sm:inline">Explore</span>
        <ArrowRight className="w-5 h-5 transition-transform group-hover:scale-125" />
      </div>

      {/* Bottom accent */}
      <div className="absolute bottom-0 left-8 right-8 h-2 bg-gradient-to-r from-amber-400 via-orange-500 to-accent rounded-full
        opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
    </button>
  );
}