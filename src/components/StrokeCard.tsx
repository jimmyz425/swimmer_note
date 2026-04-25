'use client';

import { useRouter } from 'next/navigation';
import { Compass } from 'lucide-react';

interface StrokeCardProps {
  id: string;
  name: string;
  aliases: string[];
}

export function StrokeCard({ id, name, aliases }: StrokeCardProps) {
  const router = useRouter();

  const handleClick = () => {
    router.push(`/trees/${id}`);
  };

  return (
    <button
      onClick={handleClick}
      className="lane-card min-h-[100px] md:min-h-[120px] p-4 md:p-5 flex flex-col items-center justify-center
        transition-all duration-200 splash-trigger
        hover:shadow-lg active:scale-[0.98]"
    >
      {/* Stroke name */}
      <h3 className="font-heading font-bold text-pool-dark text-lg md:text-xl text-center uppercase tracking-wide">
        {name}
      </h3>

      {/* Alias */}
      {aliases.length > 0 && (
        <p className="text-xs text-pool-mid font-medium mt-1">
          {aliases[0]}
        </p>
      )}
    </button>
  );
}

export function MasterTreeCard() {
  const router = useRouter();

  const handleClick = () => {
    router.push('/trees/master');
  };

  return (
    <button
      onClick={handleClick}
      className="lane-card min-h-[100px] md:min-h-[120px] p-4 md:p-5 flex flex-col items-center justify-center
        transition-all duration-200 splash-trigger
        hover:shadow-lg active:scale-[0.98]
        border-2 border-lane-yellow/30"
      style={{
        borderLeft: '6px solid',
        borderImage: 'repeating-linear-gradient(to bottom, #ffc107 0px, #ffc107 10px, #ff5722 10px, #ff5722 20px) 6',
      }}
    >
      {/* Icon */}
      <div className="mb-2">
        <div className="w-8 h-8 md:w-10 md:h-10 rounded-lg flex items-center justify-center"
          style={{
            background: 'linear-gradient(135deg, #ffd700 0%, #ff5722 100%)',
            boxShadow: '0 4px 12px rgba(255,215,0,0.3)',
          }}
        >
          <Compass className="w-4 h-4 md:w-5 md:h-5 text-white" />
        </div>
      </div>

      {/* Title */}
      <h3 className="font-heading font-bold text-pool-dark text-lg md:text-xl text-center uppercase tracking-wide">
        MASTER
      </h3>

      {/* Subtitle */}
      <p className="text-xs text-pool-mid font-medium mt-1">
        Core techniques
      </p>
    </button>
  );
}