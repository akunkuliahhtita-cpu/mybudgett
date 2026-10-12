export type Transaction = { id: string; amount: number; type: 'income' | 'expense'; category: string; description: string; date: string; origin?: 'recurring'; amount_original?:number;amount_rounded?:number;rounding_step?:number;rounding_difference?:number;receipt_path?:string|null };
export type Budget = { id: string; category: string; amount: number; month: string; mandatory: boolean };
export type Goal = { id: string; name: string; target: number; saved: number; monthly: number };
export type Profile = { name: string; purpose: string; pattern: string; fixed: number; project: number; projects: number; opening: number };
export const rupiah = (value: number) => new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(value).replace(/\s/g, '');
export const today = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`; };
export function summary(transactions: Transaction[], opening: number, month: string) {
 const current = transactions.filter(t => t.date.startsWith(month));
 const income = current.filter(t => t.type === 'income').reduce((s,t) => s+t.amount,0);
 const expense = current.filter(t => t.type === 'expense').reduce((s,t) => s+t.amount,0);
 const balance = opening + transactions.reduce((s,t) => s+(t.type === 'income' ? t.amount : -t.amount),0);
 return {income,expense,balance};
}
export const spent = (ts: Transaction[], category: string, month: string) => ts.filter(t=>t.type==='expense' && t.category===category && t.date.startsWith(month)).reduce((s,t)=>s+t.amount,0);
export const monthsToGoal = (g: Goal) => g.saved >= g.target ? 0 : g.monthly <= 0 ? null : Math.ceil((g.target-g.saved)/g.monthly);
export function safeToSpend(ts: Transaction[], budgets: Budget[], goals: Goal[], opening: number, month: string) { return summary(ts,opening,month).balance - budgets.filter(b=>b.month===month && b.mandatory).reduce((s,b)=>s+Math.max(0,b.amount-spent(ts,b.category,month)),0) - goals.filter(g=>g.saved<g.target).reduce((s,g)=>s+g.monthly,0); }
export function averageIncome(ts: Transaction[], month: string) { const [y,m]=month.split('-').map(Number); const months=Array.from({length:3},(_,i)=>{const d=new Date(y,m-2-i,1);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}`;}); return months.reduce((s,mo)=>s+summary(ts,0,mo).income,0)/3; }
