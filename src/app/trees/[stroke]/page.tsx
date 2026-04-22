import { TechniqueFlowchartPage } from '@/components/TechniqueFlowchart';

interface TreePageProps {
  params: Promise<{ stroke: string }>;
}

export default async function TreePage({ params }: TreePageProps) {
  const { stroke } = await params;

  return <TechniqueFlowchartPage strokeId={stroke} />;
}