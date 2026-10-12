import {adminClient} from '@/lib/admin-server';
import AdminSettings from '@/components/admin-settings';
import AdminReportRange from '@/components/admin-report-range';
export const dynamic='force-dynamic';
export default async function Page(){await adminClient();return <><AdminSettings/><div className="admin-shell"><AdminReportRange/></div></>;}
